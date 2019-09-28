import axios from '~/lib/utils/axios_utils';

import GroupsService from '~/groups/service/groups_service';
import { mockEndpoint, mockParentGroupItem } from '../mock_data';

describe('GroupsService', () => {
  let service;

  beforeEach(() => {
    service = new GroupsService(mockEndpoint);
  });

  describe('getGroups', () => {
    it('should return promise for `GET` request on provided endpoint', () => {
      spyOn(axios, 'get').and.stub();
      const params = {
        page: 2,
        filter: 'git',
        sort: 'created_asc',
        archived: true,
      };

      service.getGroups(55, 2, 'git', 'created_asc', true);

      expect(axios.get).toHaveBeenCalledWith(mockEndpoint, { params: { parent_id: 55 } });

      service.getGroups(null, 2, 'git', 'created_asc', true);

      expect(axios.get).toHaveBeenCalledWith(mockEndpoint, { params });
    });
  });

  describe('leaveGroup', () => {
    it('should return promise for `DELETE` request on provided endpoint', () => {
      spyOn(axios, 'delete').and.stub();

      service.leaveGroup(mockParentGroupItem.leavePath);

      expect(axios.delete).toHaveBeenCalledWith(mockParentGroupItem.leavePath);
    });
  });
});
