@isTest 
public class DuplicateManagerTest {
    static testMethod void NoDuplicateRecordCheck() {
        Contact objContact = new Contact();
        objContact.LastName  = 'test1';
        objContact.email ='test@test.com';
        Test.startTest();
            Sobject objContactRes = DuplicateManager.handle(objContact);
            System.assertEquals(objContactRes.Id,null);
            insert objContact;
        Test.stopTest();  
    }
    
    static testMethod void DuplicateRecordCheck() {
    
        Database.DMLOptions dml = new Database.DMLOptions();
        
            dml.DuplicateRuleHeader.AllowSave = true; 
            Contact duplicateContact= new Contact(LastName='test2',email ='test@test.com', Social_Security_Number__c = '12345678911'); 
            Database.SaveResult sr = Database.insert(duplicateContact, dml); 
            
            dml = new Database.DMLOptions();
            dml.DuplicateRuleHeader.AllowSave = true; 
            duplicateContact= new Contact(LastName='test3',email ='test@test.com'); 
            sr = Database.insert(duplicateContact, dml); 
            
            Contact objContact = new Contact();
            objContact.LastName  = 'test1';
            objContact.email ='test@test.com';
            objContact.Social_Security_Number__c = '12345678911';
            Test.startTest();
            
                Sobject objContactRes= DuplicateManager.handle(objContact);
                System.assertEquals(String.valueOf(objContactRes.get('LastName')),'test1');
                objContactRes = DuplicateManager.flag(objContact);
                System.assertEquals(Boolean.valueOF(objContactRes.get('ManualDuplicateCheck__c')),true);
                DuplicateManager.mergeRecords(duplicateContact,objContact );
                System.assertEquals(String.valueOf(duplicateContact.get('LastName')),'test1');
                DuplicateManager.SearchResult  obj = new DuplicateManager.SearchResult(duplicateContact,5);
                Integer res = obj.compareTo(obj );
                System.assertEquals(res,0);
                
            Test.stopTest();
    }
}