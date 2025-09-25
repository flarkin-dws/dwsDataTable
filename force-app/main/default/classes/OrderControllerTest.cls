/**
* This class contains unit tests for validating the behavior of Apex classes
* and triggers.
*
* Unit tests are class methods that verify whether a particular piece
* of code is working properly. Unit test methods take no arguments,
* commit no data to the database, and are flagged with the testMethod
* keyword in the method definition.
*
* All test methods in an org are executed whenever Apex code is deployed
* to a production org to confirm correctness, ensure code
* coverage, and prevent regressions. All Apex classes are
* required to have at least 75% code coverage in order to be deployed
* to a production org. In addition, all triggers must have some code coverage.
*
* The @isTest class annotation indicates this class only contains test
* methods. Classes defined with the @isTest annotation do not count against
* the org size limit for all Apex scripts.
*
* See the Apex Language Reference for more information about Testing and Code Coverage.
*/
@isTest
public class OrderControllerTest {
  private static final String STD_PRICEBOOK_NAME = 'Standard Price Book';
  private static final String PRODUCT_NAME = 'OrderCon';
  private static final String ACCOUNT_NAME = 'OrderCon Acc - Appalachia';
  private static final String ORDER_NAME = 'Order Test';
  private static final String PROCESS_DEFINITION_NAME = 'Supplies_PA2';
 
  @TestSetup
  public static void setupTestData() {
    // 1: Create an Account
    Account acc = new Account(Name = ACCOUNT_NAME, Type = '1');
    insert acc;
 
    System.debug('Inserted Account ID: ' + acc.Id);
 
    // SObject testReceiveLocation = new Location(
    //   Name = 'Test Receiving Warehouse',
    //   Inventory_Type__c = 'PA Warehouse',
    //   LocationType = ['Warehouse'],
    //   Region__c = '0Hh1U000000dfQOSAY'
    // );
    // insert testReceiveLocation;
 
    // Get standard pricebook
    Id standardPB = Test.getStandardPricebookId();
    String modifiedPB = String.valueOf(standardPB)
      .substring(0, String.valueOf(standardPB).length() - 3);
    standardPB = modifiedPB;
 
    // Create a test Product
    Product2 product = new Product2(
      Name = PRODUCT_NAME,
      IsActive = true,
      QuantityUnitOfMeasure = 'Each'
    );
    insert product;
 
    // Create standard pricebook entry
    PricebookEntry stpbe = new PricebookEntry(
      Pricebook2Id = modifiedPB,
      Product2Id = product.Id,
      UnitPrice = 777.00,
      IsActive = true
    );
    insert stpbe;
 
    // Create Order
    Order testOrder = new Order(
      Name = ORDER_NAME,
      AccountId = '0011U000015RcblQAC',
      Status = 'Working',
      EffectiveDate = Date.today(),
      Pricebook2Id = modifiedPB,
      Location__c = '1311U000000ZMvF'
    );
    insert testOrder;
 
    // Create OrderItems
    OrderItem oi1 = new OrderItem(
      OrderId = testOrder.Id,
      Product2Id = product.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 2,
      UnitPrice = 100.00,
      Status__c = 'Pending'
    );
    insert oi1;
 
    OrderItem oi2 = new OrderItem(
      OrderId = testOrder.Id,
      Product2Id = product.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 1,
      UnitPrice = 150.00,
      Status__c = 'Pending'
    );
    insert oi2;
 
    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];
 
    User testUser = new User(
      ProfileId = p.Id,
      Alias = 'OrderCon',
      Username = 'ordercon@test.com',
      Email = 'ordercon@test.com',
      FirstName = 'Order',
      LastName = 'Controller',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/New_York',
      EmailEncodingKey = 'UTF-8',
      isActive = true
    );
    insert testUser;
 
    System.runAs(testUser) {
      // Submit the Order for Approval
      Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
      req.setObjectId(testOrder.Id);
      req.setSubmitterId(testUser.Id);
      req.setProcessDefinitionNameOrId(PROCESS_DEFINITION_NAME);
      req.setSkipEntryCriteria(true);
      req.setComments('Submitting order for approval.');
 
      // Submit for Approval
      Approval.ProcessResult approvalResult = Approval.process(req);
      System.assert(approvalResult.isSuccess(), 'Approval process failed.');
    }
  }
 
  @isTest
  public static void testGetOrderWithProcessInstanceWorkitem() {
    // Query for the Order created in setupTestData
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];
 
    ProcessInstanceWorkitem workItem = [
      SELECT Id, ProcessInstanceId
      FROM ProcessInstanceWorkitem
      WHERE ProcessInstance.TargetObjectId = :ord.Id
      LIMIT 1
    ];
 
    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      workItem.Id,
      'ProcessInstanceWorkitem'
    );
    Test.stopTest();
 
    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertNotEquals(
      null,
      result.get('targetObjectId'),
      'targetObjectId should not be null'
    );
    System.assertNotEquals(
      null,
      result.get('orderProducts'),
      'orderProducts should not be null'
    );
  }
 
  @isTest
  public static void testGetOrderWithProcessInstanceStep() {
    // Query for the Order
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];
 
    // Query the ProcessInstanceStep
    ProcessInstanceStep step = [
      SELECT Id, ProcessInstanceId
      FROM ProcessInstanceStep
      WHERE ProcessInstance.TargetObjectId = :ord.Id
      LIMIT 1
    ];
 
    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      step.Id,
      'ProcessInstanceStep'
    );
    Test.stopTest();
 
    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertNotEquals(
      null,
      result.get('targetObjectId'),
      'targetObjectId should not be null'
    );
    System.assertNotEquals(
      null,
      result.get('orderProducts'),
      'orderProducts should not be null'
    );
  }
 
  @isTest
  public static void testGetOrderWithInvalidObjectType() {
    // Query for the Order
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];
 
    Test.startTest();
    try {
      OrderController.getOrder(ord.Id, 'InvalidObject');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
    Test.stopTest();
  }
 
  @isTest
  public static void testGetOrderWithBlankInputs() {
    Test.startTest();
    try {
      OrderController.getOrder('', 'ProcessInstanceWorkitem');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
 
    try {
      OrderController.getOrder('001000000000000', '');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
    Test.stopTest();
  }
}