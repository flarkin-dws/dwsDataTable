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
import ORDER_QUANTITY_FIELD from "@salesforce/schema/OrderItem.Quantity";
import ORDER_UNIT_PRICE_FIELD from "@salesforce/schema/OrderItem.UnitPrice";
import ORDER_TOTAL_PRICE_FIELD from "@salesforce/schema/OrderItem.TotalPrice";
import DESCRIPTION_FIELD from "@salesforce/schema/OrderItem.Description";

// ProductItem imports - Note: These are now handled directly in the data processing

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
    initialWidth: 140
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
    initialWidth: 140
  },
  {
    label: "Qty on Hand",
    fieldName: "QuantityOnHand",
    type: "number",
    iconName: "standard:fulfillment_order",
    cellAttributes: { alignment: "left" },
    initialWidth: 140
  },
  {
    label: "Inv Max",
    fieldName: "Maximum_Product_Inventory__c_Display",
    type: "text",
    iconName: "standard:task",
    initialWidth: 140,
    cellAttributes: { alignment: "left" },
    wrapText: true
  },
  {
    label: "Unit Price",
    fieldName: ORDER_UNIT_PRICE_FIELD.fieldApiName,
    type: "currency",
    iconName: "utility:money",
    cellAttributes: { alignment: "left" },
    initialWidth: 100,
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
    cellAttributes: { wrapText: true, alignment: "left" },
    initialWidth: 120,
    maxWidth: 400
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
            // Process the data to add warning indicators
            this.data = this.processOrderData(result.orderProducts);
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

  processOrderData(orderProducts) {
    return orderProducts.map(item => {
      const processedItem = { ...item };
      
      // Debug logging
      console.log('Processing item:', {
        productName: item.Product_Name__c,
        qtyOrdered: item.Quantity,
        qtyOnHand: item.QuantityOnHand,
        invMax: item.Maximum_Product_Inventory__c
      });
      
      // Since controller now guarantees integers, we can simplify the logic
      const qtyOrdered = item.Quantity || 0;
      const qtyOnHand = item.QuantityOnHand || 0;
      const invMax = item.Maximum_Product_Inventory__c || 0;
      
      // Only show warning if we have a valid inventory maximum > 0 and quantity data
      if (invMax > 0 && (qtyOrdered > 0 || qtyOnHand > 0)) {
        // Calculate total inventory needed (ordered + on hand)
        const totalInventoryNeeded = qtyOrdered + qtyOnHand;
        
        console.log('Inventory calculation:', {
          qtyOrdered,
          qtyOnHand,
          invMax,
          totalInventoryNeeded,
          shouldWarn: totalInventoryNeeded > invMax
        });
        
        // Add warning indicator directly to the Inv Max field
        if (totalInventoryNeeded > invMax) {
          processedItem.invMaxWarning = true;
          // Add warning icon and make it more prominent
          const warningIcon = '⚠️ '; // Using professional warning triangle
          processedItem.Maximum_Product_Inventory__c_Display = warningIcon + invMax;
          console.log('WARNING: Inventory maximum exceeded for', item.Product_Name__c);
        } else {
          processedItem.invMaxWarning = false;
          processedItem.Maximum_Product_Inventory__c_Display = invMax;
        }
      } else if (invMax === 0) {
        // Inv Max is 0, which means no limit (infinity) - never show warning
        processedItem.invMaxWarning = false;
        processedItem.Maximum_Product_Inventory__c_Display = invMax;
        console.log('No inventory maximum set (infinity) for:', item.Product_Name__c);
      } else {
        // No valid data for warning calculation
        processedItem.invMaxWarning = false;
        processedItem.Maximum_Product_Inventory__c_Display = invMax;
        console.log('No valid inventory data for warning calculation:', item.Product_Name__c);
      }
      
      return processedItem;
    });
  }
}