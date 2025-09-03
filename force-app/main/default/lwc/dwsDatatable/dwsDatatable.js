import { api, LightningElement } from "lwc";
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
const opportunityColumns = [
  {
    label: "Product Name",
    fieldName: OLI_PRODUCT_NAME_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product",
    cellAttributes: { iconName: "standard:product" },
    initialWidth: 120
  },
  {
    label: "Quantity",
    fieldName: OLI_QUANTITY_FIELD.fieldApiName,
    type: "number",
    iconName: "standard:indicator_result",
    initialWidth: 120
  },
  {
    label: "Unit Price",
    fieldName: OLI_UNIT_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "standard:price_book_entries",
    maxWidth: 120
  },
  {
    label: "Cost Plus Terms",
    fieldName: OLI_COST_PLUS_TERMS_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:price_adjustment_matrix"
  },
  {
    label: "Unit",
    fieldName: OLI_UNIT_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:catalog",
    maxWidth: 120
  },
  {
    label: "Total Price",
    fieldName: OLI_TOTAL_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "standard:currency",
    initialWidth: 140
  },
  {
    label: "Product Code",
    fieldName: OLI_PRODUCT_CODE_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product_item",
    cellAttributes: { iconName: "standard:product_item" },
    maxWidth: 143
  },
  {
    label: "Resource Grouping",
    fieldName: OLI_RESOURCE_GROUPING_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:buyer_group",
    cellAttributes: { iconName: "standard:buyer_group" }
  }
];



export default class DwsDatatable extends LightningElement {
  @api recordId; // The ID of the current record
  @api objectApiName; // The API name of the object

  isLoading = true;
  objectId;
  data;
  columns;
  error;

  connectedCallback() {
    this.fetchData();
  }

  fetchData() {
    if (this.objectApiName === 'ProcessInstanceWorkitem' || this.objectApiName === 'ProcessInstanceStep') {
      getOpportunities({
        recordId: this.recordId,
        objectName: this.objectApiName
      })
        .then((result) => {
          if (result && result.lineItems && result.lineItems.length > 0) {
            this.isLoading = false;
            this.data = result.lineItems;
            this.columns = opportunityColumns;
            this.objectId = result.targetObjectId;
          } else {
            console.warn("No opportunity line items found for this ProcessInstanceWorkitem/Step.");
            this.isLoading = false;
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