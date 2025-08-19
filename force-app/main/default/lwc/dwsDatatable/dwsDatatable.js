import { api, LightningElement, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { getRecord } from "lightning/uiRecordApi";
import getOpportunities from "@salesforce/apex/OpportunityController.getOpportunities";
import getOrder from "@salesforce/apex/OrderController.getOrder";
// OpportunityLineItem imports
import OLI_PRODUCT_NAME_FIELD from "@salesforce/schema/OpportunityLineItem.Product_Name__c";
import OLI_PRODUCT_CODE_FIELD from "@salesforce/schema/OpportunityLineItem.ProductCode";
import OLI_QUANTITY_FIELD from "@salesforce/schema/OpportunityLineItem.Quantity";
import OLI_UNIT_PRICE_FIELD from "@salesforce/schema/OpportunityLineItem.UnitPrice";
import OLI_COST_PLUS_TERMS_FIELD from "@salesforce/schema/OpportunityLineItem.Cost_Plus_Terms__c";
import OLI_UNIT_FIELD from "@salesforce/schema/OpportunityLineItem.Unit__c";
import OLI_TOTAL_PRICE_FIELD from "@salesforce/schema/OpportunityLineItem.TotalPrice";
import OLI_RESOURCE_GROUPING_FIELD from "@salesforce/schema/OpportunityLineItem.Resource_Grouping__c";

// OrderItem imports
import ORDER_PRODUCT_FIELD from "@salesforce/schema/OrderItem.Product_Name__c";
import ORDER_PRODUCT_CODE_FIELD from "@salesforce/schema/OrderItem.Product_Code__c";
import ORDER_PRIMARY_VENDOR_FIELD from "@salesforce/schema/OrderItem.Primary_Vendor__c";
import ORDER_QUANTITY_FIELD from "@salesforce/schema/OrderItem.Quantity";
import ORDER_TOTAL_QUANTITY_RECEIVED_FIELD from "@salesforce/schema/OrderItem.Total_Quantity_Received__c";
import ORDER_UNIT_PRICE_FIELD from "@salesforce/schema/OrderItem.UnitPrice";
import ORDER_TOTAL_PRICE_FIELD from "@salesforce/schema/OrderItem.TotalPrice";
import ORDER_STATUS_FIELD from "@salesforce/schema/OrderItem.Status__c";
import DESCRIPTION_FIELD from "@salesforce/schema/OrderItem.Description";
import ORDER_MODIFIED_DATE_FIELD from "@salesforce/schema/OrderItem.LastModifiedDate";

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

// OrderItem columns
const productColumns = [
  {
    label: "Product",
    fieldName: ORDER_PRODUCT_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product",
    cellAttributes: { wrapText: true, alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Code",
    fieldName: ORDER_PRODUCT_CODE_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:product_item",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Qty Ordered",
    fieldName: ORDER_QUANTITY_FIELD.fieldApiName,
    type: "number",
    iconName: "standard:indicator_result",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Qty on Hand",
    fieldName: "helloWorld-1",
    type: "number",
    iconName: "standard:fulfillment_order",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Inv Max",
    fieldName: "helloWorld-2",
    type: "text",
    iconName: "standard:task",
    initialWidth: 120,
  },
  {
    label: "Unit Price",
    fieldName: ORDER_UNIT_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "utility:money",
    cellAttributes: { alignment: "left" },
    maxWidth: 120
  },
  {
    label: "Total Price",
    fieldName: ORDER_TOTAL_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "standard:currency",
    cellAttributes: { alignment: "left" },
    initialWidth: 120
  },
  {
    label: "Line Description",
    fieldName: DESCRIPTION_FIELD.fieldApiName,
    type: "text",
    iconName: "standard:note",
    cellAttributes: { wrapText: true },
    initialWidth: 120
  },
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
      // Try Opportunity first
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
            // If no Opportunity data, try Order
            return getOrder({
              recordId: this.recordId,
              objectName: this.objectApiName
            });
          }
        })
        .then((result) => {
          if (result && result.orderProducts && result.orderProducts.length > 0) {
            this.isLoading = false;
            this.data = result.orderProducts;
            this.columns = productColumns;
            this.objectId = result.targetObjectId;
          } else {
            console.warn("No data found for this ProcessInstanceWorkitem/Step.");
          }
        })
        .catch((error) => {
          this.error = error;
          console.error("Error retrieving data:", error);
        });
    } else {
      console.warn("Unsupported object type:", this.objectApiName);
    }
  }
}