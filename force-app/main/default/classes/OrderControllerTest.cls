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
  private static final String PROCESS_DEFINITION_NAME = 'Supplies - APPALACHIA';

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

    // Create a test Product
    Product2 product = new Product2(
      Name = PRODUCT_NAME,
      IsActive = true,
      QuantityUnitOfMeasure = 'Each'
    );
    insert product;

    // Create standard pricebook entry
    PricebookEntry stpbe = new PricebookEntry(
      Pricebook2Id = standardPB,
      Product2Id = product.Id,
      UnitPrice = 777.00,
      IsActive = true
    );
    insert stpbe;

    // Create Order
    Order testOrder = new Order(
      Name = ORDER_NAME,
      AccountId = acc.Id,
      Status = 'Working',
      EffectiveDate = Date.today(),
      Pricebook2Id = standardPB
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
      // Skip process definition to make test more flexible
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

  @isTest
  public static void testGetOrderDirectly() {
    // Query for the Order
    Order ord = [
      SELECT Id, Name, Location__c
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      ord.Id,
      'Order'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(ord.Id, result.get('targetObjectId'), 'Target object ID should match');
    List<OrderItem> orderProducts = (List<OrderItem>)result.get('orderProducts');
    System.assertNotEquals(null, orderProducts, 'Order products should not be null');
    System.assertEquals(2, orderProducts.size(), 'Should have 2 order products');
  }

  @isTest
  public static void testGetOrderWithInventoryData() {
    // Query for the Order
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];

    // Create a test Location
    Schema.Location testLocation = new Schema.Location();
    testLocation.Name = 'Test Location';
    testLocation.LocationType = 'Warehouse';
    testLocation.Inventory_Type__c = 'PA Warehouse';
    testLocation.Region__c = 'Appalachia';
    insert testLocation;

    // Update Order with Location
    ord.Location__c = testLocation.Id;
    update ord;

    // Create ProductItem (inventory) records
    Product2 product = [SELECT Id FROM Product2 WHERE Name = :PRODUCT_NAME LIMIT 1];
    ProductItem inventory = new ProductItem(
      Product2Id = product.Id,
      LocationId = testLocation.Id,
      QuantityOnHand = 100,
      Maximum_Product_Inventory__c = 200
    );
    insert inventory;

    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      ord.Id,
      'Order'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(ord.Id, result.get('targetObjectId'), 'Target object ID should match');
    List<Map<String, Object>> combinedData = (List<Map<String, Object>>)result.get('orderProducts');
    System.assertNotEquals(null, combinedData, 'Combined data should not be null');
    System.assertEquals(2, combinedData.size(), 'Should have 2 order products');

    // Verify inventory data
    for (Map<String, Object> item : combinedData) {
      if (item.get('Product2Id') == product.Id) {
        System.assertEquals(100, item.get('QuantityOnHand'), 'Quantity on hand should match');
        System.assertEquals(200, item.get('Maximum_Product_Inventory__c'), 'Maximum inventory should match');
      }
    }
  }

  @isTest
  public static void testGetOrderWithNoLocation() {
    // Query for the Order (which has no Location__c set)
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      ord.Id,
      'Order'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    List<Map<String, Object>> combinedData = (List<Map<String, Object>>)result.get('orderProducts');
    System.assertNotEquals(null, combinedData, 'Combined data should not be null');
    System.assertEquals(2, combinedData.size(), 'Should have 2 order products');

    // Verify default inventory values
    for (Map<String, Object> item : combinedData) {
      System.assertEquals(0, item.get('QuantityOnHand'), 'Quantity on hand should default to 0');
      System.assertEquals(0, item.get('Maximum_Product_Inventory__c'), 'Maximum inventory should default to 0');
      System.assertEquals(false, item.get('hasWarning'), 'Should not have warning flag');
    }
  }

  @isTest
  public static void testGetOrderWithInventoryWarnings() {
    // Query for the Order
    Order ord = [
      SELECT Id
      FROM Order
      WHERE Name = :ORDER_NAME
      LIMIT 1
    ];

    // Create a test Location
    Schema.Location testLocation = new Schema.Location();
    testLocation.Name = 'Test Location';
    testLocation.LocationType = 'Warehouse';
    testLocation.Inventory_Type__c = 'PA Warehouse';
    testLocation.Region__c = 'Appalachia';
    insert testLocation;

    // Update Order with Location
    ord.Location__c = testLocation.Id;
    update ord;

    // Create ProductItem with low maximum inventory
    Product2 product = [SELECT Id FROM Product2 WHERE Name = :PRODUCT_NAME LIMIT 1];
    ProductItem inventory = new ProductItem(
      Product2Id = product.Id,
      LocationId = testLocation.Id,
      QuantityOnHand = 50,
      Maximum_Product_Inventory__c = 60 // This will trigger warning since OrderItem quantity + OnHand > Max
    );
    insert inventory;

    Test.startTest();
    Map<String, Object> result = OrderController.getOrder(
      ord.Id,
      'Order'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    List<Map<String, Object>> combinedData = (List<Map<String, Object>>)result.get('orderProducts');
    
    // Find items with warnings
    Boolean foundWarning = false;
    for (Map<String, Object> item : combinedData) {
      if (item.get('Product2Id') == product.Id) {
        System.assertEquals(true, item.get('hasWarning'), 'Should have warning flag');
        System.assertEquals(1, item.get('warningPriority'), 'Should have high warning priority');
        foundWarning = true;
      }
    }
    System.assert(foundWarning, 'Should have found at least one item with warning');
  }
}