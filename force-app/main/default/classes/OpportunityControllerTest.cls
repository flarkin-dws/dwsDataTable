/**
* Author: Frank Larkin, DWS
* This class contains a unit test for validating the behavior of the Opportunity Controller class.
*/
@isTest
public class OpportunityControllerTest {
  private static final String STD_PRICEBOOK_NAME = 'Standard Price Book';
  private static final String CUSTOMER_TYPE = 'Customer';
  private static final String PROCESS_DEFINITION_NAME = 'Opportunity_Pricing_Agreement_No_VP_req2';
 
  @TestSetup
  public static void setupTestData() {
    // Step 1: Get standard pricebook
    Id standardPB = Test.getStandardPricebookId();
    String modifiedPB = String.valueOf(standardPB)
      .substring(0, String.valueOf(standardPB).length() - 3);
    standardPB = modifiedPB;
    // Step 2: Create product
    Product2 testProduct = new Product2(
      Name = 'Test Product',
      IsActive = true,
      QuantityUnitOfMeasure = 'Each',
      ProductCode = 'TEST-001'
    );
    insert testProduct;
    // Step 3: Create pricebook entry
    PricebookEntry stpbe = new PricebookEntry(
      Pricebook2Id = modifiedPB,
      Product2Id = testProduct.Id,
      UnitPrice = 100.00,
      IsActive = true
    );
    insert stpbe;
    // Step 4: Create Test Account/Opportunity
    Account acc = new Account(
      Name = 'Test Account',
      Type = 'Customer',
      Account_Active__c = true
    );
    insert acc;
    Opportunity testOpportunity = new Opportunity(
      Name = 'Test Opportunity',
      AccountId = acc.Id,
      StageName = 'New',
      Pricebook2Id = modifiedPB,
      CloseDate = Date.today()
    );
    insert testOpportunity;
    // Step 5: Create Opportunity Products (OpportunityLineItems)
    OpportunityLineItem oli1 = new OpportunityLineItem(
      OpportunityId = testOpportunity.Id,
      Product2Id = testProduct.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 2,
      UnitPrice = 100.00
    );
    insert oli1;
    OpportunityLineItem oli2 = new OpportunityLineItem(
      opportunityId = testOpportunity.Id,
      Product2Id = testProduct.Id,
      PricebookEntryId = stpbe.Id,
      Quantity = 1,
      UnitPrice = 150.00
    );
    insert oli2;
    // Step 6: Get a User to test as
    User testUser = [SELECT Id FROM User WHERE Profile.Name LIKE 'System Admin%' AND IsActive = true LIMIT 1];
    System.runAs(testUser) {
      // 6a: Submit the opportunity for Approval
      Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
      req.setObjectId(testOpportunity.Id);
      req.setSubmitterId(testUser.Id);
      req.setProcessDefinitionNameOrId(PROCESS_DEFINITION_NAME);
      req.setSkipEntryCriteria(true);
      req.setComments('Submitting opportunity for approval.');
      // 6b: Submit for Approval
      Approval.ProcessResult approvalResult = Approval.process(req);
      System.assert(approvalResult.isSuccess(), 'Approval process failed.');
    }
  }

  /**
  @isTest
  public static void testGetopportunityWithBlankInputs() {
    Test.startTest();
    try {
      OpportunityController.getOpportunities('001000000000000AAA');
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
 
    try {
      OpportunityController.getOpportunities(null);
      System.assert(false, 'Should have thrown an exception');
    } catch (AuraHandledException e) {
      System.assert(true, 'Exception thrown as expected');
    }
    Test.stopTest();
  }
   */

  // passing
  @isTest
  public static void testGetOppLineItemsWithValidOpportunity() {
    // Query for the test opportunity
    Opportunity testOpp = [
      SELECT Id
      FROM Opportunity
      WHERE Name = 'Test Opportunity'
      LIMIT 1
    ];
    
    Test.startTest();
    Map<String, Object> result = OpportunityController.getOpportunities(testOpp.Id);
    Test.stopTest();
    
    // Verify the results
    System.assertNotEquals(null, result, 'Result should not be null');
    System.assertNotEquals(null, result.get('targetObjectId'), 'TargetObjectId should not be null');
    System.assertNotEquals(null, result.get('lineItems'), 'LineItems should not be null');
    
    List<OpportunityLineItem> lineItems = (List<OpportunityLineItem>) result.get('lineItems');
    System.assertEquals(2, lineItems.size(), 'Should return 2 opportunity line items');
    System.assertEquals(testOpp.Id, result.get('targetObjectId'), 'TargetObjectId should match the opportunity ID');
  }

}