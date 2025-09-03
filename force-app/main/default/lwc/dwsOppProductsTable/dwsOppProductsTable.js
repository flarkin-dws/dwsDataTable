import { api, LightningElement } from "lwc";
import getOpportunityLineItems from "@salesforce/apex/OpportunityController.getOpportunityLineItemsByOrder";
import getOpportunityLineItemsWithDetails from "@salesforce/apex/OpportunityController.getOpportunityLineItemsByOrderWithDetails";
import getOpportunities from "@salesforce/apex/OpportunityController.getOpportunities";

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
  @api recordId; // The ID of the current record (Order or ProcessInstanceWorkitem/Step)
  @api objectApiName; // The API name of the object

  isLoading = true;
  data;
  columns;
  error;

  connectedCallback() {
    this.fetchData();
  }

  fetchData() {
    console.log('fetchData called with recordId:', this.recordId, 'objectApiName:', this.objectApiName);
    
    if (this.objectApiName === 'ProcessInstanceWorkitem' || this.objectApiName === 'ProcessInstanceStep') {
      // Handle approval pages - get opportunity line items through the approval process
      console.log('Fetching data for approval page...');
      getOpportunities({
        recordId: this.recordId,
        objectName: this.objectApiName
      })
        .then((result) => {
          console.log('getOpportunities result:', result);
          if (result && result.lineItems && result.lineItems.length > 0) {
            this.isLoading = false;
            this.data = result.lineItems;
            this.columns = opportunityProductColumns;
            console.log('Successfully loaded', result.lineItems.length, 'opportunity line items');
          } else {
            console.warn("No opportunity line items found for this ProcessInstanceWorkitem/Step.");
            this.isLoading = false;
            this.data = [];
          }
        })
        .catch((error) => {
          this.error = error;
          console.error("Error retrieving opportunity data:", error);
          this.isLoading = false;
        });
    } else if (this.objectApiName === 'Order') {
      // Handle Order record pages - get opportunity line items related to this order
      console.log('Fetching data for Order page...');
      getOpportunityLineItemsWithDetails({
        orderId: this.recordId
      })
        .then((result) => {
          console.log('getOpportunityLineItemsWithDetails result:', result);
          if (result && result.lineItems && result.lineItems.length > 0) {
            this.isLoading = false;
            this.data = result.lineItems;
            this.columns = opportunityProductColumns;
            console.log('Successfully loaded', result.lineItems.length, 'opportunity line items');
            console.log('Opportunity details:', {
              hasOpportunity: result.hasOpportunity,
              opportunityId: result.opportunityId,
              opportunityName: result.opportunityName,
              accountName: result.accountName
            });
          } else {
            console.warn("No opportunity line items found for this Order.");
            console.log('Result details:', {
              hasOpportunity: result?.hasOpportunity,
              message: result?.message
            });
            this.isLoading = false;
            this.data = [];
          }
        })
        .catch((error) => {
          this.error = error;
          console.error("Error retrieving opportunity line items:", error);
          this.isLoading = false;
        });
    } else {
      console.warn("Unsupported object type:", this.objectApiName);
      this.isLoading = false;
    }
  }
}