// Seeds Opportunity Loss Reason test scenarios.
// Idempotent: deletes every record previously seeded (marked by SEED_DESCRIPTION), then recreates them.
// Run with: sf apex run --file scripts/apex/seed-test-data.apex --target-org case-alma-dev

String SEED_DESCRIPTION = 'Seeded test data';
Date today = Date.today();
Date openCloseDate = today.addDays(30);

// 1. Clean up previously seeded records (Opportunities first, then Accounts)
// Description is a Long Text Area on Account and Opportunity, so SOQL cannot filter on it.
// Accounts are found by the names this script creates; the Description check in Apex is a safety net
// so a manually created account with the same name is never deleted.
Set<String> seedAccountNames = new Set<String>{'Burger Group', 'Solo Café', 'XXL Chain', 'Closed Deal Inc', 'Burger Paris', 'Burger Lyon', 'Burger Bordeaux', 'Burger Lille', 'Burger Marseille', 'Burger Nantes', 'Burger Bordeaux Airport'};
for (Integer storeNumber = 1; storeNumber <= 60; storeNumber++) {
    seedAccountNames.add('XXL Store ' + (storeNumber < 10 ? '0' : '') + String.valueOf(storeNumber));
}

List<Account> previousAccounts = new List<Account>();
for (Account candidate : [SELECT Id, Description FROM Account WHERE Name IN :seedAccountNames]) {
    if (candidate.Description == SEED_DESCRIPTION) {
        previousAccounts.add(candidate);
    }
}

List<Opportunity> previousOpportunities = new List<Opportunity>();
Set<Id> previousAccountIds = new Map<Id, Account>(previousAccounts).keySet();
if (!previousAccountIds.isEmpty()) {
    for (Opportunity candidate : [SELECT Id, Description FROM Opportunity WHERE AccountId IN :previousAccountIds]) {
        if (candidate.Description == SEED_DESCRIPTION) {
            previousOpportunities.add(candidate);
        }
    }
}
delete previousOpportunities;
delete previousAccounts;
System.debug('Deleted previous seed data: ' + previousOpportunities.size() + ' opportunities, ' + previousAccounts.size() + ' accounts.');

// 2. Root accounts (no parent)
List<Account> rootAccounts = new List<Account>{
    new Account(Name = 'Burger Group', Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'Solo Café', Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'XXL Chain', Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'Closed Deal Inc', Lifecycle_Status__c = 'Customer', Description = SEED_DESCRIPTION)
};
insert rootAccounts;

Map<String, Account> rootAccountsByName = new Map<String, Account>();
for (Account rootAccount : rootAccounts) {
    rootAccountsByName.put(rootAccount.Name, rootAccount);
}

// 3. First-level children of Burger Group and XXL Chain
Id burgerGroupId = rootAccountsByName.get('Burger Group').Id;
Id xxlChainId = rootAccountsByName.get('XXL Chain').Id;

List<Account> childAccounts = new List<Account>{
    new Account(Name = 'Burger Paris', ParentId = burgerGroupId, Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'Burger Lyon', ParentId = burgerGroupId, Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'Burger Bordeaux', ParentId = burgerGroupId, Lifecycle_Status__c = 'Prospect', Description = SEED_DESCRIPTION),
    new Account(Name = 'Burger Lille', ParentId = burgerGroupId, Lifecycle_Status__c = 'Nurturing', Nurturing_Stage_Date__c = today.addDays(-60), Description = SEED_DESCRIPTION),
    new Account(Name = 'Burger Marseille', ParentId = burgerGroupId, Lifecycle_Status__c = 'Customer', Description = SEED_DESCRIPTION),
    new Account(Name = 'Burger Nantes', ParentId = burgerGroupId, Lifecycle_Status__c = 'Churned', Description = SEED_DESCRIPTION)
};
for (Integer storeNumber = 1; storeNumber <= 60; storeNumber++) {
    String storeNumberLabel = (storeNumber < 10 ? '0' : '') + String.valueOf(storeNumber);
    childAccounts.add(new Account(
        Name = 'XXL Store ' + storeNumberLabel,
        ParentId = xxlChainId,
        Lifecycle_Status__c = 'Prospect',
        Description = SEED_DESCRIPTION
    ));
}
insert childAccounts;

Map<String, Account> childAccountsByName = new Map<String, Account>();
for (Account childAccount : childAccounts) {
    childAccountsByName.put(childAccount.Name, childAccount);
}

// 4. Grandchild of Burger Group (parent = Burger Bordeaux)
List<Account> grandchildAccounts = new List<Account>{
    new Account(
        Name = 'Burger Bordeaux Airport',
        ParentId = childAccountsByName.get('Burger Bordeaux').Id,
        Lifecycle_Status__c = 'Prospect',
        Description = SEED_DESCRIPTION
    )
};
insert grandchildAccounts;

// 5. Opportunities (all open deals: Prospecting, close date today + 30; the won deal closes today)
Account soloCafe = rootAccountsByName.get('Solo Café');
Account closedDealInc = rootAccountsByName.get('Closed Deal Inc');
Account burgerParis = childAccountsByName.get('Burger Paris');

List<Opportunity> opportunities = new List<Opportunity>{
    new Opportunity(
        Name = 'Burger Group - Network Deal',
        AccountId = burgerGroupId,
        StageName = 'Prospecting',
        CloseDate = openCloseDate,
        Description = SEED_DESCRIPTION
    ),
    new Opportunity(
        Name = 'Solo Café - Deal',
        AccountId = soloCafe.Id,
        StageName = 'Prospecting',
        CloseDate = openCloseDate,
        Description = SEED_DESCRIPTION
    ),
    new Opportunity(
        Name = 'XXL Chain - Network Deal',
        AccountId = xxlChainId,
        StageName = 'Prospecting',
        CloseDate = openCloseDate,
        Description = SEED_DESCRIPTION
    ),
    new Opportunity(
        Name = 'Burger Paris - Local Deal',
        AccountId = burgerParis.Id,
        StageName = 'Prospecting',
        CloseDate = openCloseDate,
        Description = SEED_DESCRIPTION
    ),
    new Opportunity(
        Name = 'Closed Deal Inc - Won Deal',
        AccountId = closedDealInc.Id,
        StageName = 'Closed Won',
        CloseDate = today,
        Description = SEED_DESCRIPTION
    )
};
insert opportunities;

// 6. Summary
List<Account> allSeededAccounts = new List<Account>();
allSeededAccounts.addAll(rootAccounts);
allSeededAccounts.addAll(childAccounts);
allSeededAccounts.addAll(grandchildAccounts);

System.debug('=== Seed summary ===');
System.debug('Accounts created: ' + allSeededAccounts.size());
System.debug('Opportunities created: ' + opportunities.size());
for (Opportunity opportunity : opportunities) {
    System.debug('  - ' + opportunity.Name + ' [' + opportunity.StageName + ']');
}
