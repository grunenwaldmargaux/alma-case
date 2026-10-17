import { LightningElement, api, wire } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getChildAccounts from '@salesforce/apex/ChildAccountSelectorController.getChildAccounts';

const ACCOUNT_PAGE_PATH = '/lightning/r/Account/';

const ACCOUNT_COLUMNS = [
    {
        label: 'Account Name',
        fieldName: 'accountUrl',
        type: 'url',
        typeAttributes: { label: { fieldName: 'name' }, target: '_blank' }
    },
    { label: 'Lifecycle Status', fieldName: 'lifecycleStatus', type: 'text' },
    { label: 'Owner', fieldName: 'ownerName', type: 'text' }
];

export default class ChildAccountSelector extends LightningElement {
    @api recordId;
    @api masterAccountId;
    @api selectedAccountIds = [];
    @api selectedCount = 0;

    columns = ACCOUNT_COLUMNS;
    searchTerm = '';
    eligibleAccounts = [];
    ineligibleAccounts = [];
    selectedIds = new Set();
    isLoaded = false;
    errorMessage;

    get effectiveMasterId() {
        return this.masterAccountId || this.recordId;
    }

    get hasMasterAccount() {
        return Boolean(this.effectiveMasterId);
    }

    get isLoading() {
        return this.hasMasterAccount && !this.isLoaded && !this.errorMessage;
    }

    get showContent() {
        return this.hasMasterAccount && this.isLoaded && !this.errorMessage;
    }

    get visibleEligibleAccounts() {
        return this.filterByName(this.eligibleAccounts);
    }

    get visibleIneligibleAccounts() {
        return this.filterByName(this.ineligibleAccounts);
    }

    get hasNoEligibleAccounts() {
        return this.eligibleAccounts.length === 0;
    }

    get hasVisibleEligibleAccounts() {
        return this.visibleEligibleAccounts.length > 0;
    }

    get hasEligibleButNoMatch() {
        return !this.hasNoEligibleAccounts && !this.hasVisibleEligibleAccounts;
    }

    get hasVisibleIneligibleAccounts() {
        return this.visibleIneligibleAccounts.length > 0;
    }

    get isSearchActive() {
        return this.searchTerm.trim() !== '';
    }

    get eligibleHeading() {
        return this.formatHeading('Eligible child accounts', this.visibleEligibleAccounts.length, this.eligibleAccounts.length);
    }

    get ineligibleHeading() {
        return this.formatHeading('Not eligible child accounts', this.visibleIneligibleAccounts.length, this.ineligibleAccounts.length);
    }

    formatHeading(label, visibleCount, totalCount) {
        return this.isSearchActive ? `${label} (${visibleCount}/${totalCount})` : `${label} (${totalCount})`;
    }

    get selectedLabel() {
        return `${this.selectedIds.size} account(s) selected`;
    }

    get selectedRows() {
        return this.visibleEligibleAccounts
            .filter(account => this.selectedIds.has(account.id))
            .map(account => account.id);
    }

    @wire(getChildAccounts, { masterAccountId: '$effectiveMasterId' })
    wiredChildAccounts({ data, error }) {
        if (data) {
            const accounts = data.map(account => ({
                ...account,
                accountUrl: ACCOUNT_PAGE_PATH + account.id + '/view'
            }));
            this.eligibleAccounts = accounts.filter(account => account.isEligible);
            this.ineligibleAccounts = accounts.filter(account => !account.isEligible);
            this.errorMessage = undefined;
            this.isLoaded = true;
            this.keepOnlyEligibleSelections();
        } else if (error) {
            this.eligibleAccounts = [];
            this.ineligibleAccounts = [];
            this.errorMessage = reduceErrorMessage(error);
            this.isLoaded = true;
        }
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value;
    }

    handleRowSelection(event) {
        // The table only reports rows that are visible under the current search, so selections hidden by the filter are kept.
        const visibleIds = new Set(this.visibleEligibleAccounts.map(account => account.id));
        const hiddenSelectedIds = [...this.selectedIds].filter(id => !visibleIds.has(id));
        const visibleSelectedIds = event.detail.selectedRows.map(row => row.id);
        this.updateSelection([...hiddenSelectedIds, ...visibleSelectedIds]);
    }

    keepOnlyEligibleSelections() {
        const eligibleIds = new Set(this.eligibleAccounts.map(account => account.id));
        this.updateSelection([...this.selectedIds].filter(id => eligibleIds.has(id)));
    }

    updateSelection(ids) {
        this.selectedIds = new Set(ids);
        this.selectedAccountIds = [...this.selectedIds];
        this.selectedCount = this.selectedIds.size;
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedAccountIds', this.selectedAccountIds));
        this.dispatchEvent(new FlowAttributeChangeEvent('selectedCount', this.selectedCount));
    }

    filterByName(accounts) {
        const term = this.searchTerm.trim().toLowerCase();
        if (!term) {
            return accounts;
        }
        return accounts.filter(account => account.name.toLowerCase().includes(term));
    }
}

function reduceErrorMessage(error) {
    return error?.body?.message || 'Could not load child accounts. Refresh the page or contact your administrator.';
}
