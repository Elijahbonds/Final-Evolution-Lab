import { mutationRef, executeMutation, validateArgs } from 'firebase/data-connect';

export const connectorConfig = {
  connector: 'admin',
  service: 'elijahbonds',
  location: 'us-east4'
};
export const appendShardLedgerRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'AppendShardLedger', inputVars);
}
appendShardLedgerRef.operationName = 'AppendShardLedger';

export function appendShardLedger(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(appendShardLedgerRef(dcInstance, inputVars));
}

export const createCreatorCardCatalogItemRef = (dcOrVars, vars) => {
  const { dc: dcInstance, vars: inputVars} = validateArgs(connectorConfig, dcOrVars, vars, true);
  dcInstance._useGeneratedSdk();
  return mutationRef(dcInstance, 'CreateCreatorCardCatalogItem', inputVars);
}
createCreatorCardCatalogItemRef.operationName = 'CreateCreatorCardCatalogItem';

export function createCreatorCardCatalogItem(dcOrVars, vars) {
  const { dc: dcInstance, vars: inputVars } = validateArgs(connectorConfig, dcOrVars, vars, true);
  return executeMutation(createCreatorCardCatalogItemRef(dcInstance, inputVars));
}

