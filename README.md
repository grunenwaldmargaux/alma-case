# Close Lost Opportunity – Alma Revenue Systems Lead Case Study

A Sales rep closes a lost deal on a **Master Account** and, in the same step, moves some of its **Child Accounts** to **Nurturing**.

---

## How it works

```
Opportunity page
 └─ "Close Lost Opportunity" button  (Quick Action, shown only while IsClosed = false)
     └─ Screen Flow
         1. Get the child accounts of the opportunity's account
         2. One screen:
            - Loss Reason (required)
            - childAccountSelector LWC        (if the account has children)
            - or "<Account> has no child accounts. Only the opportunity will be closed."
            - button "Close as Lost"
         3. Update the selected accounts → Lifecycle Status = Nurturing, Nurturing Stage Date = today
         4. Update the opportunity       → Stage = Closed Lost, Loss Reason
         5. Confirmation screen
         If step 3 or 4 fails → roll back everything, email the admin, show an error screen
```

| Component | Type | Role |
|---|---|---|
| `Lifecycle_Status__c` | Account field (picklist) | Prospect, Customer, Nurturing, Churned |
| `Nurturing_Stage_Date__c` | Account field (date) | When the account entered Nurturing |
| `Loss_Reason__c` | Opportunity field (picklist) | Why the deal was lost |
| `Loss_Reason_Required_When_Closed_Lost` | Validation rule | No Closed Lost without a reason, whatever the entry point |
| `childAccountSelector` | LWC | Child account selection |
| `ChildAccountSelectorController` | Apex | Returns direct children with eligibility and reason |
| `OPP_Close_lost_opp_put_child_accounts_in_Nurturing_stage` | Screen Flow | Orchestration and updates |
| `Opportunity.Close_Lost_Opportunity` | Quick Action | The button |
| `Opportunity_Record_Page1` | Lightning page | Shows the button through Dynamic Actions |
| `Close_Lost_Flow_Error_Recipient` | Custom label | Admin email notified on errors |
| `Close_Lost_Network` | Permission set | Field, Apex and flow access for Revenue users |

---

## Decision: accounts already in Nurturing

**Already-Nurturing children are shown, greyed out, and cannot be selected.**

- **Shown**, so reps see the whole network and never think an account is missing.
- **Not selectable**, because moving them again adds nothing.
- **Not refreshed**: their `Nurturing_Stage_Date__c` keep its original values, so we keep track of when the account first entered Nurturing.

The same rule applies to **active customers**: a customer must never be moved to Nurturing by mistake (e.g. group expansion, where some children of the network are already live).

The LWC therefore shows two tables and both use the custom LWC:

- **Eligible accounts**: Prospect and Churned children, with checkboxes and select-all.
- **Not eligible**: greyed out, with the reason: *Already in Nurturing*, *Active customer* or *No edit access*.

> Two tables instead of one, because `lightning-datatable` cannot disable a single row's checkbox.

---

## Edge cases

### Handled

| Edge case | Behaviour |
|---|---|
| Account has no children | Message on screen, LWC hidden; the rep can still close lost the opportunity |
| No eligible child | All children listed under "Not eligible"; the rep can still close lost the opportunity |
| Rep selects no account | Allowed: only the opportunity is closed |
| Child already in Nurturing / active customer | Greyed out, not selectable |
| Large network | Search by name, "(X of N)" counters, selection kept while filtering. Edit access checked in chunks of 200 (platform limit) |
| Grandchildren | Not shown: direct children only, as per the brief |
| Loss Reason missing | Required on screen + validation rule on the object |
| Opportunity already closed | Button hidden (`IsClosed = false`), the button being the only entry point to the flow |
| An update fails (validation rule, record locking…) | Shared fault path: **rollback of all changes**, email to the admin with the error, readable error screen for the rep. All or nothing: never a closed opportunity with half-updated accounts |
| Rep closes the window before clicking "Close as Lost" | Nothing is saved |

### Identified, not handled

| Edge case | Why / next step |
|---|---|
| Opportunity without an account | Not expected: opportunities always live on the master account. Next step: a Decision at the start of the flow with an explicit message |
| Opportunity on a child account | Same assumption. The flow would list the child's own children. Next step: warn the rep, or walk up to the master |

---

## Assumptions & open questions

- **Which children were in scope of the deal?** No data links an opportunity to specific children, so **the rep decides**. A future improvement would be a junction object (Opportunity ↔ Account) to track the deal's real scope to be able to handle partial launches within a master account.
- `Lifecycle_Status__c` is a new field, distinct from the standard `Type`: `Type` describes the nature of the relationship, not the commercial lifecycle. Mixing both would pollute reporting.
- Churned accounts are eligible for Nurturing: they can be re-engaged.

---

## Other design choices

- **Loss Reason uses a Picklist Choice Set** bound to the field: one source of truth, new values appear in the flow automatically.
- **Field-level security via a permission set**, no profile changes: least privilege, safer deployments.
- **Apex runs `with sharing` and `WITH USER_MODE`**: reps only see what they are allowed to see.
- **Error recipient in a custom label**: changeable per org without editing the flow.
- **Handled faults + admin email** rather than unhandled faults: reps get a clear message instead of a generic error, and the admin still gets notified, with more context than the standard flow error email. I would also use a logger package (my preferred is Nebula Logger) to log the flow error + send a slack notification in a dedicated channel for immediate response if needed. 

---

## Testing

- **Apex**: 9 tests, 100% coverage of `ChildAccountSelectorController` (eligibility rules, rule order, grandchildren excluded, empty master, 250-child network, user without edit access).
- **Test data**: `scripts/apex/seed-test-data.apex` is idempotent and creates one scenario per network: Burger Group (mixed statuses + a grandchild), Solo Café (no children), XXL Chain (60 children), an opportunity on a child account, and a Closed Won opportunity.
- **Manual test plan**: run the button on each seeded opportunity, re-running the seed script between runs to reset the data.