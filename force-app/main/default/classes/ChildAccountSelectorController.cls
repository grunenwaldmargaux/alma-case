public with sharing class ChildAccountSelectorController {

    private static final String STATUS_NURTURING = 'Nurturing';
    private static final String STATUS_CUSTOMER = 'Customer';
    private static final Integer USER_RECORD_ACCESS_MAX_IDS = 200;

    @AuraEnabled(cacheable=true)
    public static List<ChildAccountRow> getChildAccounts(Id masterAccountId) {
        if (masterAccountId == null) {
            return new List<ChildAccountRow>();
        }

        List<Account> childAccounts = [
            SELECT Id, Name, Lifecycle_Status__c, Owner.Name
            FROM Account
            WHERE ParentId = :masterAccountId
            WITH USER_MODE
            ORDER BY Name
        ];

        Map<Id, Boolean> hasEditAccessByAccountId = getEditAccessByAccountId(childAccounts);

        List<ChildAccountRow> rows = new List<ChildAccountRow>();
        for (Account childAccount : childAccounts) {
            rows.add(buildRow(childAccount, hasEditAccessByAccountId.get(childAccount.Id)));
        }
        return rows;
    }

    // UserRecordAccess accepts at most 200 RecordIds per query, so the IDs are queried in chunks of 200.
    private static Map<Id, Boolean> getEditAccessByAccountId(List<Account> accounts) {
        Map<Id, Boolean> hasEditAccessByAccountId = new Map<Id, Boolean>();
        Set<Id> chunkAccountIds = new Set<Id>();
        for (Account childAccount : accounts) {
            chunkAccountIds.add(childAccount.Id);
            if (chunkAccountIds.size() == USER_RECORD_ACCESS_MAX_IDS) {
                addEditAccess(chunkAccountIds, hasEditAccessByAccountId);
                chunkAccountIds = new Set<Id>();
            }
        }
        if (!chunkAccountIds.isEmpty()) {
            addEditAccess(chunkAccountIds, hasEditAccessByAccountId);
        }
        return hasEditAccessByAccountId;
    }

    private static void addEditAccess(Set<Id> accountIds, Map<Id, Boolean> hasEditAccessByAccountId) {
        for (UserRecordAccess access : [
            SELECT RecordId, HasEditAccess
            FROM UserRecordAccess
            WHERE UserId = :UserInfo.getUserId() AND RecordId IN :accountIds
        ]) {
            hasEditAccessByAccountId.put(access.RecordId, access.HasEditAccess);
        }
    }

    private static ChildAccountRow buildRow(Account childAccount, Boolean hasEditAccess) {
        ChildAccountRow row = new ChildAccountRow();
        row.id = childAccount.Id;
        row.name = childAccount.Name;
        row.lifecycleStatus = childAccount.Lifecycle_Status__c;
        row.ownerName = childAccount.Owner.Name;
        row.ineligibleReason = getIneligibleReason(childAccount.Lifecycle_Status__c, hasEditAccess);
        row.isEligible = row.ineligibleReason == null;
        return row;
    }

    // First matching rule wins. A missing access record is treated as no access.
    private static String getIneligibleReason(String lifecycleStatus, Boolean hasEditAccess) {
        if (lifecycleStatus == STATUS_NURTURING) {
            return 'Already in Nurturing';
        }
        if (lifecycleStatus == STATUS_CUSTOMER) {
            return 'Active customer';
        }
        if (hasEditAccess != true) {
            return 'No edit access';
        }
        return null;
    }

    public class ChildAccountRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String lifecycleStatus;
        @AuraEnabled public String ownerName;
        @AuraEnabled public Boolean isEligible;
        @AuraEnabled public String ineligibleReason;
    }
}
