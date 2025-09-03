import { api, LightningElement } from "lwc";
import getOrder from "@salesforce/apex/OrderController.getOrder";

// OrderItem imports
import ORDER_PRODUCT_FIELD from "@salesforce/schema/OrderItem.Product_Name__c";
import ORDER_PRODUCT_CODE_FIELD from "@salesforce/schema/OrderItem.Product_Code__c";
import ORDER_QUANTITY_FIELD from "@salesforce/schema/OrderItem.Quantity";
import ORDER_UNIT_PRICE_FIELD from "@salesforce/schema/OrderItem.UnitPrice";
import ORDER_TOTAL_PRICE_FIELD from "@salesforce/schema/OrderItem.TotalPrice";
import DESCRIPTION_FIELD from "@salesforce/schema/OrderItem.Description";

// OrderItem columns
const orderProductColumns = [
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

export default class DwsOrderProductsTable extends LightningElement {
  @api recordId; // The ID of the current record
  @api objectApiName; // The API name of the object

  isLoading = true;
  objectId;
  data;
  columns;
  error;

  // Computed property to check if we should display the component
  get shouldDisplay() {
    // Check if recordId exists and starts with '801'
    if (!this.recordId) return false;
    
    // For approval processes, we need to check the target object ID
    if (this.objectId && String(this.objectId).startsWith('801')) {
      return true;
    }
    
    // For direct Order record pages
    return String(this.recordId).startsWith('801');
  }

  connectedCallback() {
    // Add debug logging for initialization
    console.log('Component initialized with:', {
      recordId: this.recordId,
      objectApiName: this.objectApiName,
      type: typeof this.objectApiName
    });
    
    // Ensure objectApiName is set for Order record pages
    if (!this.objectApiName && this.recordId && this.recordId.startsWith('801')) {
      console.log('Setting objectApiName to Order based on record ID prefix');
      this.objectApiName = 'Order';
    }
    
    this.fetchData();
  }

  fetchData() {
    console.log('fetchData called with recordId:', this.recordId, 'objectApiName:', this.objectApiName);

    if (this.objectApiName === 'ProcessInstanceWorkitem' || this.objectApiName === 'ProcessInstanceStep') {
      // Handle approval pages - get order products through the approval process
      console.log('Fetching data for approval page...');
      getOrder({
        recordId: this.recordId,
        objectName: this.objectApiName
      })
        .then((result) => {
          console.log('getOrder result:', result);
          if (result && result.orderProducts && result.orderProducts.length > 0) {
            this.isLoading = false;
            // Process the data to add warning indicators
            this.data = this.processOrderData(result.orderProducts);
            this.columns = orderProductColumns;
            this.objectId = result.targetObjectId;
            console.log('Successfully loaded', result.orderProducts.length, 'order products');
          } else {
            console.warn("No order products found for this ProcessInstanceWorkitem/Step.");
            this.isLoading = false;
            this.data = [];
          }
        })
        .catch((error) => {
          this.error = error;
          console.error("Error retrieving order data:", error);
          this.isLoading = false;
        });
    } else if (this.objectApiName === 'Order') {
      // Handle Order record pages - get order products directly
      console.log('Fetching data for Order page...');
      getOrder({
        recordId: this.recordId,
        objectName: this.objectApiName
      })
        .then((result) => {
          console.log('getOrder result:', result);
          if (result && result.orderProducts && result.orderProducts.length > 0) {
            this.isLoading = false;
            // Process the data to add warning indicators
            this.data = this.processOrderData(result.orderProducts);
            this.columns = orderProductColumns;
            console.log('Successfully loaded', result.orderProducts.length, 'order products');
          } else {
            console.warn("No order products found for this Order.");
            this.isLoading = false;
            this.data = [];
          }
        })
        .catch((error) => {
          console.error("Error retrieving order data:", {
            error: error,
            recordId: this.recordId,
            objectApiName: this.objectApiName,
            message: error.body?.message || error.message
          });
          this.error = error.body?.message || error.message || 'Unknown error occurred';
          this.isLoading = false;
        });
    } else {
      console.warn("Unsupported object type:", this.objectApiName);
      this.isLoading = false;
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
