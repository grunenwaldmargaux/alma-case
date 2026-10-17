@IsTest
private class ChildAccountSelectorControllerTest {

    private static final String MASTER_WITH_CHILDREN = 'Test Master Chain';
    private static final String MASTER_WITHOUT_CHILDREN = 'Test Lonely Master';
    private static final String PROSPECT_STORE = 'Test Prospect Store';
    private static final String CHURNED_STORE = 'Test Churned Store';
    private static final String NURTURING_STORE = 'Test Nurturing Store';
    private static final String CUSTOMER_STORE = 'Test Customer Store';
    private static final String GRANDCHILD_STORE = 'Test Grandchild Store';

    @TestSetup
    static void createTestData() {
        Account masterWithChildren = new Account(Name = MASTER_WITH_CHILDREN, Lifecycle_Status__c = 'Prospect');
        Account masterWithoutChildren = new Account(Name = MASTER_WITHOUT_CHILDREN, Lifecycle_Status__c = 'Prospect');
        insert new List<Account>{ masterWithChildren, masterWithoutChildren };

        Account prospectStore = new Account(Name = PROSPECT_STORE, ParentId = masterWithChildren.Id, Lifecycle_Status__c = 'Prospect');
        Account churnedStore = new Account(Name = CHURNED_STORE, ParentId = masterWithChildren.Id, Lifecycle_Status__c = 'Churned');
        Account nurturingStore = new Account(Name = NURTURING_STORE, ParentId = masterWithChildren.Id, Lifecycle_Status__c = 'Nurturing');
        Account customerStore = new Account(Name = CUSTOMER_STORE, ParentId = masterWithChildren.Id, Lifecycle_Status__c = 'Customer');
        insert new List<Account>{ prospectStore, churnedStore, nurturingStore, customerStore };

        insert new Account(Name = GRANDCHILD_STORE, ParentId = prospectStore.Id, Lifecycle_Status__c = 'Prospect');
    }

    @IsTest
    static void prospectAndChurnedChildrenAreEligible() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        ChildAccountSelectorController.ChildAccountRow prospectRow = getRowByName(rows, PROSPECT_STORE);
        Assert.isTrue(prospectRow.isEligible, 'A Prospect child should be eligible.');
        Assert.isNull(prospectRow.ineligibleReason, 'An eligible Prospect child should have no ineligible reason.');

        ChildAccountSelectorController.ChildAccountRow churnedRow = getRowByName(rows, CHURNED_STORE);
        Assert.isTrue(churnedRow.isEligible, 'A Churned child should be eligible.');
        Assert.isNull(churnedRow.ineligibleReason, 'An eligible Churned child should have no ineligible reason.');
    }

    @IsTest
    static void childrenAreReturnedOrderedByName() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        Assert.areEqual(4, rows.size(), 'Only the four direct children should be returned.');
        Assert.areEqual(CHURNED_STORE, rows[0].name, 'Children should be ordered by Name ascending.');
        Assert.areEqual(CUSTOMER_STORE, rows[1].name, 'Children should be ordered by Name ascending.');
        Assert.areEqual(NURTURING_STORE, rows[2].name, 'Children should be ordered by Name ascending.');
        Assert.areEqual(PROSPECT_STORE, rows[3].name, 'Children should be ordered by Name ascending.');
    }

    @IsTest
    static void nurturingChildIsIneligible() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        ChildAccountSelectorController.ChildAccountRow nurturingRow = getRowByName(rows, NURTURING_STORE);
        Assert.isFalse(nurturingRow.isEligible, 'A Nurturing child should not be eligible.');
        Assert.areEqual('Already in Nurturing', nurturingRow.ineligibleReason, 'A Nurturing child should report the Nurturing reason.');
    }

    @IsTest
    static void customerChildIsIneligible() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        ChildAccountSelectorController.ChildAccountRow customerRow = getRowByName(rows, CUSTOMER_STORE);
        Assert.isFalse(customerRow.isEligible, 'A Customer child should not be eligible.');
        Assert.areEqual('Active customer', customerRow.ineligibleReason, 'A Customer child should report the Active customer reason.');
    }

    @IsTest
    static void childrenWithoutEditAccessAreIneligibleUnlessAnEarlierRuleApplies() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);
        User readOnlyUser = createReadOnlyUser();

        List<ChildAccountSelectorController.ChildAccountRow> rows;
        System.runAs(readOnlyUser) {
            Test.startTest();
            rows = ChildAccountSelectorController.getChildAccounts(masterId);
            Test.stopTest();
        }

        ChildAccountSelectorController.ChildAccountRow prospectRow = getRowByName(rows, PROSPECT_STORE);
        Assert.isFalse(prospectRow.isEligible, 'A Prospect child without edit access should not be eligible.');
        Assert.areEqual('No edit access', prospectRow.ineligibleReason, 'A Prospect child without edit access should report the No edit access reason.');

        ChildAccountSelectorController.ChildAccountRow customerRow = getRowByName(rows, CUSTOMER_STORE);
        Assert.areEqual('Active customer', customerRow.ineligibleReason, 'The Customer rule should take precedence over the edit access rule.');

        ChildAccountSelectorController.ChildAccountRow nurturingRow = getRowByName(rows, NURTURING_STORE);
        Assert.areEqual('Already in Nurturing', nurturingRow.ineligibleReason, 'The Nurturing rule should take precedence over the edit access rule.');
    }

    @IsTest
    static void grandchildrenAreExcluded() {
        Id masterId = getAccountId(MASTER_WITH_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        Assert.isFalse(hasRowNamed(rows, GRANDCHILD_STORE), 'Grandchildren must not be returned; only direct children are selectable.');
    }

    @IsTest
    static void masterWithoutChildrenReturnsEmptyList() {
        Id masterId = getAccountId(MASTER_WITHOUT_CHILDREN);

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Test.stopTest();

        Assert.isTrue(rows.isEmpty(), 'A master account without children should return an empty list.');
    }

    @IsTest
    static void nullMasterReturnsEmptyList() {
        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(null);
        Test.stopTest();

        Assert.isTrue(rows.isEmpty(), 'A null master account id should return an empty list without querying.');
    }

    @IsTest
    static void networkLargerThanOneAccessChunkIsFullyEvaluated() {
        // UserRecordAccess takes at most 200 RecordIds per query, so 250 children need two access queries.
        Id masterId = getAccountId(MASTER_WITHOUT_CHILDREN);
        List<Account> bulkChildren = new List<Account>();
        for (Integer index = 0; index < 250; index++) {
            bulkChildren.add(new Account(Name = 'Test Bulk Store ' + index, ParentId = masterId, Lifecycle_Status__c = 'Prospect'));
        }
        insert bulkChildren;

        Test.startTest();
        List<ChildAccountSelectorController.ChildAccountRow> rows = ChildAccountSelectorController.getChildAccounts(masterId);
        Integer queriesUsed = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(250, rows.size(), 'All 250 children should be returned.');
        for (ChildAccountSelectorController.ChildAccountRow row : rows) {
            Assert.isTrue(row.isEligible, 'Child ' + row.name + ' should be eligible; edit access must be found in every chunk, not only the first 200.');
        }
        Assert.isTrue(queriesUsed <= 3, 'Expected at most 3 SOQL queries for 250 children (accounts plus two access chunks), but used ' + queriesUsed + '.');
    }

    private static Id getAccountId(String accountName) {
        return [SELECT Id FROM Account WHERE Name = :accountName LIMIT 1].Id;
    }

    private static Boolean hasRowNamed(List<ChildAccountSelectorController.ChildAccountRow> rows, String accountName) {
        for (ChildAccountSelectorController.ChildAccountRow row : rows) {
            if (row.name == accountName) {
                return true;
            }
        }
        return false;
    }

    private static ChildAccountSelectorController.ChildAccountRow getRowByName(List<ChildAccountSelectorController.ChildAccountRow> rows, String accountName) {
        for (ChildAccountSelectorController.ChildAccountRow row : rows) {
            if (row.name == accountName) {
                return row;
            }
        }
        Assert.fail('Expected a row named ' + accountName + ' but none was returned.');
        return null;
    }

    // Profile names are translated per org language, so the profile is found by its permissions:
    // the first internal (Salesforce licence) profile that cannot edit Account records.
    private static User createReadOnlyUser() {
        List<ObjectPermissions> accountPermissions = [
            SELECT Parent.ProfileId
            FROM ObjectPermissions
            WHERE SobjectType = 'Account'
                AND PermissionsEdit = false
                AND Parent.IsOwnedByProfile = true
                AND Parent.Profile.UserLicense.Name = 'Salesforce'
            LIMIT 1
        ];
        Assert.isFalse(accountPermissions.isEmpty(), 'The org needs an internal profile without Account edit access to run this test.');

        User readOnlyUser = new User(
            Alias = 'rdonly',
            Email = 'child.selector.test@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Child Selector Test',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = accountPermissions[0].Parent.ProfileId,
            TimeZoneSidKey = 'Europe/Paris',
            Username = 'child.selector.test.' + String.valueOf(DateTime.now().getTime()) + '@example.com'
        );
        insert readOnlyUser;

        // The controller reads Lifecycle_Status__c in USER_MODE, so the user needs field access to it.
        // Close_Lost_Network is the permission set that grants this to sales reps.
        PermissionSet closeLostNetwork = [SELECT Id FROM PermissionSet WHERE Name = 'Close_Lost_Network' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = readOnlyUser.Id, PermissionSetId = closeLostNetwork.Id);
        return readOnlyUser;
    }
}
