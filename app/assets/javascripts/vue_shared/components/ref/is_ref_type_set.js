import { getParameterByName } from '~/lib/utils/url_utility';
import { REF_TYPE_PARAM_NAME, TAG_REF_TYPE, BRANCH_REF_TYPE } from './constants';

// The ambiguous ref modal is not needed once the URL picks a branch or a tag.
export const isRefTypeSet = () => {
  const refType = getParameterByName(REF_TYPE_PARAM_NAME);

  return refType === TAG_REF_TYPE || refType === BRANCH_REF_TYPE;
};
