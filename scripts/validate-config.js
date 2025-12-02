// node ./scripts/validate-config.js
const fs = require("fs");
const path = require("path");

const files = fs.readdirSync(path.join(__dirname, "jsons"));
for (const file of files) {
  const config = JSON.parse(
    fs.readFileSync(path.join(__dirname, "jsons", file), "utf8")
  );
  for (let i = 0; i < config.merkle_proofs.length; i++) {
    const merkleProof = config.merkle_proofs[i];
    const innerParameters = merkleProof.description.innerParameters;
    const innerParametersNames = Object.keys(innerParameters);
    for (let j = 0; j < merkleProof.description.abi.inputs.length; j++) {
      const abiInput = merkleProof.description.abi.inputs[j];
      if (!innerParameters[abiInput.name]) {
        console.log(
          `File ${file} has missing inner parameter "${abiInput.name}" for ${merkleProof.description.description}. Did you mean "${innerParametersNames[j]}"?`
        );
      }
    }
  }
}
