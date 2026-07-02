const { mutationRef, executeMutation, validateArgs } = require('firebase/data-connect');

const connectorConfig = {
  connector: 'admin',
  service: 'elijahbonds',
  location: 'us-east4'
};
exports.connectorConfig = connectorConfig;

const appendShardLedgerRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'AppendShardLedger', inputVars);
}
appendShardLedgerRef.operationName = 'AppendShardLedger';
exports.appendShardLedgerRef = appendShardLedgerRef;

exports.appendShardLedger = function appendShardLedger(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(appendShardLedgerRef(dcInstance, inputVars));
}
;

const createCreatorCardCatalogItemRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCreatorCardCatalogItem', inputVars);
}
createCreatorCardCatalogItemRef.operationName = 'CreateCreatorCardCatalogItem';
exports.createCreatorCardCatalogItemRef = createCreatorCardCatalogItemRef;

exports.createCreatorCardCatalogItem = function createCreatorCardCatalogItem(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCreatorCardCatalogItemRef(dcInstance, inputVars));
}
;
