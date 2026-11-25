import { stateKey } from './state_maps';

export default function deviseState() {
  if (this.preparing) {
    return stateKey.preparing;
  }
  if (!this.commitsCount) {
    return stateKey.nothingToMerge;
  }
  if (this.projectArchived) {
    return stateKey.archived;
  }
  if (this.branchMissing) {
    return stateKey.missingBranch;
  }
  if (this.canMerge && this.isSHAMismatch) {
    return stateKey.shaMismatch;
  }
  if (!this.autoMergeEnabled && this.preferredAutoMergeStrategy) {
    return stateKey.readyToMerge;
  }
  if (
    !this.mergeabilityChecks ||
    this.mergeabilityChecks.some(({ status }) => status === 'CHECKING')
  ) {
    return null;
  }
  if (this.mergeabilityChecks.some(({ status }) => status === 'FAILED')) {
    return stateKey.mergeChecksFailed;
  }
  return stateKey.readyToMerge;
}
