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
      // Dynamically construct the query
      String query =
        'SELECT Id, ProcessInstance.TargetObjectId FROM ' +
        objectName +
        ' WHERE Id = :recordId LIMIT 1';
      SObject record = Database.query(query);

      // Casting to the appropriate object type and process
      String targetObjectId;
      if (record instanceof ProcessInstanceStep) {
        ProcessInstanceStep step = (ProcessInstanceStep) record;
        if (
          step.ProcessInstance == null ||
          step.ProcessInstance.TargetObjectId == null
        ) {
          throw new AuraHandledException(
            'The ProcessInstance or TargetObjectId is null.'
          );
        }
        targetObjectId = step.ProcessInstance.TargetObjectId;
      } else if (record instanceof ProcessInstanceWorkitem) {
        ProcessInstanceWorkitem workItem = (ProcessInstanceWorkitem) record;
        if (
          workItem.ProcessInstance == null ||
          workItem.ProcessInstance.TargetObjectId == null
        ) {
          throw new AuraHandledException(
            'The ProcessInstance or TargetObjectId is null.'
          );
        }
        targetObjectId = workItem.ProcessInstance.TargetObjectId;
      } else {
        throw new AuraHandledException('Unexpected object type.');
      }

      System.debug('TargetObjectId: ' + targetObjectId);
      result.put('targetObjectId', targetObjectId);

      // Querying the Order Products related to the Order
      List<OrderItem> orderProducts = [
        SELECT
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

      //adding the results
      result.put('orderProducts', orderProducts);
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
}