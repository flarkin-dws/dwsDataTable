public with sharing class OrderController {
  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getOrder(
    String recordId,
    String objectName
  ) {
    Map<String, Object> result = new Map<String, Object>();
    System.debug(
      'Method getOrderData called with recordId: ' +
        recordId +
        ', objectName: ' +
        objectName
    );

    if (String.isBlank(recordId) || String.isBlank(objectName)) {
      System.debug('Error: recordId or objectName is blank.');
      throw new AuraHandledException(
        'Invalid input: Id and objectName cannot be blank.'
      );
    }

    try {
      String targetObjectId;
      
      if (objectName == 'Order') {
        targetObjectId = recordId;
      } else if (objectName == 'ProcessInstanceStep' || objectName == 'ProcessInstanceWorkitem') {
        // For approval process records, we need to query differently
        
        // First try ProcessInstanceWorkitem
        List<ProcessInstanceWorkitem> workItems = [
          SELECT ProcessInstance.TargetObjectId 
          FROM ProcessInstanceWorkitem 
          WHERE Id = :recordId
          LIMIT 1
        ];
        
        if (!workItems.isEmpty() && workItems[0].ProcessInstance != null) {
          targetObjectId = workItems[0].ProcessInstance.TargetObjectId;
        } else {
          // If not found, try ProcessInstanceStep
          List<ProcessInstanceStep> steps = [
            SELECT ProcessInstance.TargetObjectId 
            FROM ProcessInstanceStep 
            WHERE Id = :recordId
            LIMIT 1
          ];
          
          if (!steps.isEmpty() && steps[0].ProcessInstance != null) {
            targetObjectId = steps[0].ProcessInstance.TargetObjectId;
          }
        }
        
        if (String.isBlank(targetObjectId)) {
          throw new AuraHandledException('Could not find target Order record.');
        }
      } else {
        throw new AuraHandledException('Unexpected object type: ' + objectName);
      }

      System.debug('TargetObjectId: ' + targetObjectId);
      result.put('targetObjectId', targetObjectId);

      // First, get the Order to find the receiving location
      Order orderRecord = [
        SELECT Id, Location__c
        FROM Order
        WHERE Id = :targetObjectId
        LIMIT 1
      ];
      
      System.debug('Order Location: ' + orderRecord.Location__c);
      result.put('orderLocation', orderRecord.Location__c);

      // Querying the Order Products related to the Order
      List<OrderItem> orderProducts = [
        SELECT
          Id,
          Product2Id,
          Product_Name__c,
          Product_Code__c,
          Primary_Vendor__c,
          Quantity,
          Total_Quantity_Received__c,
          UnitPrice,
          TotalPrice,
          Status__c,
          Description,
          LastModifiedDate
        FROM OrderItem
        WHERE OrderId = :targetObjectId
        ORDER BY TotalPrice DESC
      ];

      System.debug('Order Products retrieved: ' + orderProducts);

      // Query ProductItem data to get inventory information by Product2Id and Location
      Set<Id> product2Ids = new Set<Id>();
      for (OrderItem item : orderProducts) {
        if (item.Product2Id != null) {
          product2Ids.add(item.Product2Id);
        }
      }

      Map<Id, ProductItem> productItemMap = new Map<Id, ProductItem>();
      if (!product2Ids.isEmpty() && String.isNotBlank(orderRecord.Location__c)) {
        List<ProductItem> productItems = [
          SELECT
            Product2Id,
            QuantityOnHand,
            Maximum_Product_Inventory__c,
            LocationId
          FROM ProductItem
          WHERE Product2Id IN :product2Ids
          AND LocationId = :orderRecord.Location__c
        ];
        
        System.debug('ProductItems found: ' + productItems.size() + ' for location: ' + orderRecord.Location__c);
        
        for (ProductItem pi : productItems) {
          // Use Product2Id as the key since we're matching by ID
          productItemMap.put(pi.Product2Id, pi);
          System.debug('ProductItem mapped: ' + pi.Product2Id + ' -> QtyOnHand: ' + pi.QuantityOnHand + ', MaxInv: ' + pi.Maximum_Product_Inventory__c);
        }
      } else {
        System.debug('No Product2Ids or order location available for ProductItem query');
      }

      // Combine OrderItem and ProductItem data
      List<Map<String, Object>> combinedData = new List<Map<String, Object>>();
      for (OrderItem item : orderProducts) {
        Map<String, Object> combinedItem = new Map<String, Object>();
        
        // Add all OrderItem fields
        combinedItem.put('Id', item.Id);
        combinedItem.put('Product_Name__c', item.Product_Name__c);
        combinedItem.put('Product_Code__c', item.Product_Code__c);
        combinedItem.put('Primary_Vendor__c', item.Primary_Vendor__c);
        // Convert Quantity to integer for proper comparison
        Integer qtyOrdered = item.Quantity != null ? Integer.valueOf(item.Quantity) : 0;
        combinedItem.put('Quantity', qtyOrdered);
        combinedItem.put('Total_Quantity_Received__c', item.Total_Quantity_Received__c);
        combinedItem.put('UnitPrice', item.UnitPrice);
        combinedItem.put('TotalPrice', item.TotalPrice);
        combinedItem.put('Status__c', item.Status__c);
        combinedItem.put('Description', item.Description);
        combinedItem.put('LastModifiedDate', item.LastModifiedDate);
        
        // Add ProductItem fields if available
        if (item.Product2Id != null && productItemMap.containsKey(item.Product2Id)) {
          ProductItem pi = productItemMap.get(item.Product2Id);
          // Convert to integers to ensure proper comparison
          Integer qtyOnHand = pi.QuantityOnHand != null ? Integer.valueOf(pi.QuantityOnHand) : 0;
          Integer maxInv = pi.Maximum_Product_Inventory__c != null ? Integer.valueOf(pi.Maximum_Product_Inventory__c) : 0;
          
          combinedItem.put('QuantityOnHand', qtyOnHand);
          combinedItem.put('Maximum_Product_Inventory__c', maxInv);
          
          // Add a warning flag for sorting purposes
          if (maxInv > 0 && (qtyOrdered + qtyOnHand) > maxInv) {
            combinedItem.put('hasWarning', true);
            combinedItem.put('warningPriority', 1); // High priority for sorting
          } else {
            combinedItem.put('hasWarning', false);
            combinedItem.put('warningPriority', 0); // Normal priority
          }
          
          System.debug('ProductItem data added for ' + item.Product_Name__c + ' (Product2Id: ' + item.Product2Id + ', Location: ' + orderRecord.Location__c + '): QtyOnHand=' + qtyOnHand + ', MaxInv=' + maxInv + ', HasWarning=' + combinedItem.get('hasWarning'));
        } else {
          combinedItem.put('QuantityOnHand', 0);
          combinedItem.put('Maximum_Product_Inventory__c', 0);
          combinedItem.put('hasWarning', false);
          combinedItem.put('warningPriority', 0);
          System.debug('No ProductItem data found for Product2Id: ' + item.Product2Id + ' at Location: ' + orderRecord.Location__c);
        }
        
        combinedData.add(combinedItem);
      }

      // Sort the combined data: warning items first, then by original order
      combinedData.sort(new WarningPriorityComparator());
      
      //adding the results
      result.put('orderProducts', combinedData);
      
      // Debug: Log the combined data structure
      for (Map<String, Object> item : combinedData) {
        System.debug('Combined item: ' + item);
      }
    } catch (Exception e) {
      System.debug('Error occurred: ' + e.getMessage());
      System.debug('Stack trace: ' + e.getStackTraceString());
      throw new AuraHandledException(
        'Error retrieving opportunity data: ' + e.getMessage()
      );
    }
    System.debug('Result: ' + result);
    System.debug('Result: ' + result.keySet());
    return result;
  }
  
  // Comparator class to sort items with warnings first
  public class WarningPriorityComparator implements Comparator<Map<String, Object>> {
    public Integer compare(Map<String, Object> item1, Map<String, Object> item2) {
      Boolean hasWarning1 = (Boolean) item1.get('hasWarning');
      Boolean hasWarning2 = (Boolean) item2.get('hasWarning');
      
      // If both have same warning status, maintain original order
      if (hasWarning1 == hasWarning2) {
        return 0;
      }
      
      // Items with warnings (true) come before items without warnings (false)
      return hasWarning1 ? -1 : 1;
    }
  }
}