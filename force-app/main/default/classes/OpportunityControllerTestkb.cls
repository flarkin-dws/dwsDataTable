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
public class OpportunityControllerTestkb {
  private static final String STD_PRICEBOOK_NAME = 'Standard Price Book';
  private static final String CUSTOM_PRICEBOOK_NAME = 'Custom Price Book';
  private static final String PRODUCT_NAME = 'OppCon';
  private static final String ACCOUNT_NAME = 'OppCon Acc';
  private static final String CLIENT_TYPE = 'Associate';
  private static final String OPPORTUNITY_NAME = 'Opp Test';
  private static final String PROCESS_DEFINITION_NAME = 'Billable - APPALACHIA';

  @TestSetup
  static void setupTestData() {
    // 1: Create an Account
    Account acc = new Account(Name = ACCOUNT_NAME, Type = '1');
    insert acc;

    System.debug('Inserted Account ID: ' + acc.Id);

    // KB Get standard pricebook
    Id standardPB = Test.getStandardPricebookId();
    String modifiedPB = String.valueOf(standardPB)
      .substring(0, String.valueOf(standardPB).length() - 3);
    standardPB = modifiedPB;
    System.debug('Standard Pricebook ID:--------------------- ' + standardPB);
    System.debug(
      'Standard Pricebook ID MODIFIED:--------------------- ' + modifiedPB
    );

    // 2. Create a test Opportunity
    Opportunity opp = new Opportunity(
      Name = OPPORTUNITY_NAME,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(10),
      Region__c = 'Appalachia',
      Pricebook2Id = standardPB,
      AccountId = acc.Id
    );
    insert opp;
    System.debug('Inserted Opportunity ID:------------------------ ' + opp.Id);

    // 3. Create a Product
    Product2 product = new Product2(
      Name = PRODUCT_NAME,
      IsActive = true,
      QuantityUnitOfMeasure = 'Each'
    );
    insert product;
    System.debug('Inserted Product ID:------------------------ ' + product.Id);

    // 4. KB Create standard pricebook entry
    PricebookEntry stpbe = new PricebookEntry(
      Pricebook2Id = standardPB,
      Product2Id = product.Id,
      UnitPrice = 777.00,
      IsActive = true
    );
    insert stpbe;

    // 5. KB Get Opp pricebook and add product to it. This is pricebook id used by the opportunity
    string oppPb = opp.Pricebook2Id;
    System.debug('Opp Pricebook:------------------------ ' + oppPb);

    // Step 4: Create OpportunityLineItems related to the Opportunity
    OpportunityLineItem oli1 = new OpportunityLineItem(
      OpportunityId = opp.Id,
      Product2Id = product.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 2,
      UnitPrice = 100.00
    );
    insert oli1;
    System.debug(
      'Inserted OpportunityLineItem 1 ID:------------------------ ' + oli1.Id
    );

    OpportunityLineItem oli2 = new OpportunityLineItem(
      OpportunityId = opp.Id,
      Product2Id = product.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 1,
      UnitPrice = 150.00
    );
    insert oli2;
    System.debug(
      'Inserted OpportunityLineItem 2 ID:------------------------ ' + oli2.Id
    );

    Profile p = [
      SELECT Id
      FROM Profile
      WHERE Name = 'System Administrator'
      LIMIT 1
    ];

    User testUser = new User(
      ProfileId = p.Id,
      Alias = 'OppCon',
      // Nickname = 'test',
      Username = 'oppcon@test.com',
      Email = 'oppcon@test.com',
      FirstName = 'Opportunity',
      LastName = 'Controller',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      TimeZoneSidKey = 'America/New_York',
      EmailEncodingKey = 'UTF-8',
      // UserLicense = 'Salesforce',
      // Role = 'Administrator',
      isActive = true
    );
    insert testUser;

    System.debug('Inserted User ID:------------------------ ' + testUser.Id);

    System.runAs(testUser) {
      // Submit the Opportunity for Approval
      Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
      req.setObjectId(opp.Id);
      req.setSubmitterId(testUser.Id);
      req.setProcessDefinitionNameOrId(PROCESS_DEFINITION_NAME);
      req.setSkipEntryCriteria(true);
      req.setComments('Submitting opportunity for approval.');

      // Submit for Approval
      Approval.ProcessResult approvalResult = Approval.process(req);
      System.assert(approvalResult.isSuccess(), 'Approval process failed.');
      System.debug('Approval Process Submitted.');
    }
  }

  @isTest
  static void testGetOpportunitiesWithProcessInstanceWorkitem() {
    // Query for the Opportunity created in setupTestData
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = :OPPORTUNITY_NAME
      LIMIT 1
    ];

    ProcessInstanceWorkitem workItem = [
      SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
      FROM ProcessInstanceWorkitem
      WHERE ProcessInstance.TargetObjectId = :opp.Id
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = OpportunityController.getOpportunities(
      workItem.Id,
      'ProcessInstanceWorkitem'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(opp.Id, result.get('targetObjectId'), 'Target object ID should match');
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>)result.get('lineItems');
    System.assertNotEquals(null, lineItems, 'Line items should not be null');
    System.assertEquals(2, lineItems.size(), 'Should have 2 line items');
  }
  
  @isTest
  static void testGetOpportunitiesWithProcessInstanceStep() {
    // Query for the Opportunity
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = :OPPORTUNITY_NAME
      LIMIT 1
    ];

    // Query the ProcessInstanceStep
    ProcessInstanceStep step = [
      SELECT Id, ProcessInstanceId, ProcessInstance.TargetObjectId
      FROM ProcessInstanceStep
      WHERE ProcessInstance.TargetObjectId = :opp.Id
      LIMIT 1
    ];

    Test.startTest();
    Map<String, Object> result = OpportunityController.getOpportunities(
      step.Id,
      'ProcessInstanceStep'
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(opp.Id, result.get('targetObjectId'), 'Target object ID should match');
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>)result.get('lineItems');
    System.assertNotEquals(null, lineItems, 'Line items should not be null');
    System.assertEquals(2, lineItems.size(), 'Should have 2 line items');
  }

  @isTest
  static void testGetOpportunitiesWithInvalidObjectType() {
    // Query for the Opportunity
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = :OPPORTUNITY_NAME
      LIMIT 1
    ];

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      OpportunityController.getOpportunities(opp.Id, 'InvalidObject');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }

  @isTest
  static void testGetOpportunitiesWithBlankInputs() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      OpportunityController.getOpportunities('', 'ProcessInstanceWorkitem');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');

    exceptionThrown = false;
    try {
      OpportunityController.getOpportunities('001000000000000', '');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }

  @isTest
  static void testGetOpportunitiesWithNullProcessInstance() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      // Use a non-existent ID that matches ProcessInstanceWorkitem ID format
      OpportunityController.getOpportunities('04i000000000001', 'ProcessInstanceWorkitem');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }

  @isTest
  static void testGetOpportunitiesWithNullTargetObjectId() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      // Use a non-existent ID that matches ProcessInstanceStep ID format
      OpportunityController.getOpportunities('04r000000000001', 'ProcessInstanceStep');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }

  @isTest
  static void testGetOpportunityLineItemsByOrder() {
    // Query for the Opportunity
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = :OPPORTUNITY_NAME
      LIMIT 1
    ];

    // Create a test Order linked to the Opportunity
    Order testOrder = new Order(
      AccountId = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1].Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      OpportunityId = opp.Id,
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert testOrder;

    Test.startTest();
    List<OpportunityLineItem> result = OpportunityController.getOpportunityLineItemsByOrder(
      testOrder.Id
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(2, result.size(), 'Should have 2 line items');
  }

  @isTest
  static void testGetOpportunityLineItemsByOrderWithDetails() {
    // Query for the Opportunity
    Opportunity opp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = :OPPORTUNITY_NAME
      LIMIT 1
    ];

    // Create a test Order linked to the Opportunity
    Order testOrder = new Order(
      AccountId = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1].Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      OpportunityId = opp.Id,
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert testOrder;

    Test.startTest();
    Map<String, Object> result = OpportunityController.getOpportunityLineItemsByOrderWithDetails(
      testOrder.Id
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(true, result.get('hasOpportunity'), 'Should have an associated opportunity');
    System.assertEquals(opp.Id, result.get('opportunityId'), 'Opportunity ID should match');
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>)result.get('lineItems');
    System.assertEquals(2, lineItems.size(), 'Should have 2 line items');
  }

  @isTest
  static void testGetOpportunityLineItemsByOrderWithNoOpportunity() {
    // Create a test Order without linking to an Opportunity
    Order testOrder = new Order(
      AccountId = [SELECT Id FROM Account WHERE Name = :ACCOUNT_NAME LIMIT 1].Id,
      EffectiveDate = Date.today(),
      Status = 'Draft',
      Pricebook2Id = Test.getStandardPricebookId()
    );
    insert testOrder;

    Test.startTest();
    Map<String, Object> result = OpportunityController.getOpportunityLineItemsByOrderWithDetails(
      testOrder.Id
    );
    Test.stopTest();

    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertEquals(false, result.get('hasOpportunity'), 'Should not have an associated opportunity');
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>)result.get('lineItems');
    System.assertEquals(0, lineItems.size(), 'Should have no line items');
  }

  @isTest
  static void testGetOpportunityLineItemsByOrderWithInvalidId() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      OpportunityController.getOpportunityLineItemsByOrder('invalid_id');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');

    exceptionThrown = false;
    try {
      OpportunityController.getOpportunityLineItemsByOrderWithDetails('invalid_id');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }

  @isTest
  static void testGetOpportunityLineItemsByOrderWithBlankId() {
    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      OpportunityController.getOpportunityLineItemsByOrder('');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');

    exceptionThrown = false;
    try {
      OpportunityController.getOpportunityLineItemsByOrderWithDetails('');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(exceptionThrown, 'An AuraHandledException should have been thrown');
    Test.stopTest();
  }
}