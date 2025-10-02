import { api, LightningElement } from "lwc";
import getOpportunities from "@salesforce/apex/OpportunityController.getOpportunities";
//import getOpportunityLineItems from "@salesforce/apex/OpportunityController.getOpportunityLineItems";

// OpportunityLineItem imports
import OLI_PRODUCT_NAME_FIELD from "@salesforce/schema/OpportunityLineItem.Product_Name__c";
import OLI_PRODUCT_CODE_FIELD from "@salesforce/schema/OpportunityLineItem.ProductCode";
import OLI_QUANTITY_FIELD from "@salesforce/schema/OpportunityLineItem.Quantity";
import OLI_UNIT_PRICE_FIELD from "@salesforce/schema/OpportunityLineItem.UnitPrice";
import OLI_COST_PLUS_TERMS_FIELD from "@salesforce/schema/OpportunityLineItem.Cost_Plus_Terms__c";
import OLI_UNIT_FIELD from "@salesforce/schema/OpportunityLineItem.Unit__c";
import OLI_TOTAL_PRICE_FIELD from "@salesforce/schema/OpportunityLineItem.TotalPrice";
import OLI_RESOURCE_GROUPING_FIELD from "@salesforce/schema/OpportunityLineItem.Resource_Grouping__c";

// OpportunityLineItem columns
const opportunityProductColumns = [
  {
    label: "Product",
    fieldName: OLI_PRODUCT_NAME_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product",
    cellAttributes: { wrapText: true, alignment: "left" },
    initialWidth: 140
  },
  {
    label: "Code",
    fieldName: OLI_PRODUCT_CODE_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product_item",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Quantity",
    fieldName: OLI_QUANTITY_FIELD.fieldApiName,
    type: "number",
    iconName: "standard:indicator_result",
    cellAttributes: { alignment: "left" },
    initialWidth: 140
  },
  {
    label: "Unit",
    fieldName: OLI_UNIT_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:catalog",
    cellAttributes: { alignment: "left" },
    initialWidth: 100
  },
  {
    label: "Unit Price",
    fieldName: OLI_UNIT_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "utility:money",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Total Price",
    fieldName: OLI_TOTAL_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "standard:currency",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Cost Plus Terms",
    fieldName: OLI_COST_PLUS_TERMS_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:price_adjustment_matrix",
    cellAttributes: { wrapText: true, alignment: "left" },
    initialWidth: 150
  },
  {
    label: "Resource Grouping",
    fieldName: OLI_RESOURCE_GROUPING_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:buyer_group",
    cellAttributes: { alignment: "left" },
    initialWidth: 140
  }
];

export default class DwsOppProductsTable extends LightningElement {
  @api recordId; // The ID of the current record (ProcessInstanceWorkitem/Step)
  @api objectApiName; // The API name of the object

  isLoading = true;
  objectId;
  data = [];
  columns;
  error;
  testString;

  // Computed property for the card title
  get cardTitle() {
    if (!this.shouldDisplay) return '';
    return 'Opportunity Products';
  }

  // Computed property for the card icon
  get cardIcon() {
    if (!this.shouldDisplay) return '';
    return 'standard:opportunity_line_item';
  }

  get shouldDisplay() {
    // First check if we have a recordId
    if (!this.recordId) return false;
    
    // Handle direct Opportunity pages
    if (this.objectApiName === 'Opportunity') {
      return String(this.recordId).startsWith('006') && this.hasData;
    }
    
    // Handle approval process pages
    if (this.objectApiName === 'ProcessInstanceWorkitem' || this.objectApiName === 'ProcessInstanceStep') {
      // Only show if we have opportunity line items and a valid target object
      return this.hasData && this.objectId;
    } 
    
    return false;
  }

  // Helper computed property to check if we have data to display
  get hasData() {
    return this.data && this.data.length > 0;
  }

  connectedCallback() {
    // Add debug logging for initialization
    console.log('Component initialized with:', {
      recordId: this.recordId,
      objectApiName: this.objectApiName,
      type: typeof this.objectApiName
    });
    
    // Fetch data for supported object types
    if (this.objectApiName === 'Opportunity' || 
        this.objectApiName === 'ProcessInstanceWorkitem' || 
        this.objectApiName === 'ProcessInstanceStep') {
      this.fetchData();
    } else {
      this.isLoading = false;
      console.log('Not fetching data - unsupported object type:', this.objectApiName);
    }
  }

  fetchData() {
    console.log('[JS 144] fetchData called with recordId:', this.recordId, 'objectApiName:', this.objectApiName);
    
    if (this.objectApiName === 'ProcessInstanceWorkitem' || this.objectApiName === 'ProcessInstanceStep') {
      // Handle approval pages - get opportunity line items through the approval process
      console.log('[JS 148] This is a ProcessInstanceWorkItem or ProcessInstanceStep.' + this.recordId);
      getOpportunities({
        recordId: this.recordId,
      })
        .then((result) => {
          console.log('[Line 154] testString (should be ProcessInstanceId) result:', this.testString);
          console.log('[Line 155] getOpportunities result:', result);
          this.isLoading = false;
          // Handle the new Map response structure
          if (result && result.lineItems && result.lineItems.length > 0) {
            // Ensure each line item has an Id field for the datatable key-field
            this.data = result.lineItems.map((item, index) => ({
              ...item,
              id: item.Id || `row-${index}` // Use existing Id or create a unique key
            }));
            this.objectId = result.targetObjectId;
            console.log('[JS 160] objectId:', this.objectId);
            console.log('[JS 161] Processed data:', this.data);
            console.log('[JS 162] shouldDisplay after data load:', this.shouldDisplay);
            this.columns = opportunityProductColumns;
            console.log('Successfully loaded', result.lineItems.length, 'opportunity line items for opportunity:', result.targetObjectId);
          } else {
            console.warn("No opportunity line items found for this ProcessInstanceWorkitem/Step.");
            this.data = [];
          }
        })
        .catch((error) => {
          this.error = error;
          console.error("Error retrieving opportunity data:", error);
          this.isLoading = false;
        });
    } else {
      console.warn("Unsupported object type:", this.objectApiName);
      this.isLoading = false;
    }
  }
}