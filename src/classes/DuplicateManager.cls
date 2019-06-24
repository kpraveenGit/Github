public without  sharing class DuplicateManager {
    
   /**
   * Method to check for the existence of the record before its creation.
   * Returns the Sobject if no duplicate exist,returns merge record if confidence level > threshold value
   * and flags the record for manual duplicate check if the confidence value > fagging threshold. 
   * @return [Sobject]
   * @author Stian Ruud Schikora updatedd
   */
    public static sObject handle(sObject obj){
        //Search for duplicates
        SearchResult[] result = search(obj);
        System.debug('********Inside handle**********'+result );
        //No duplicates found then return the sobject for creation.
        if(result.isEmpty()) return obj;
        //Identify best match
        result.sort(); //Sort ascending
        SearchResult top = result.get(result.size()-1); //Get last
        
        //Return match if it has a certain certainty
        //Identify the Sobject name by passing record Id.
        Id myId = String.valueOf(top.record.get('Id'));
        String sObjName = myId.getSObjectType().getDescribe().getName();
        
        //Query the Custom metadata for getting the configuration by passing object name.
        List<Merge_Field_Setting__mdt>  lstThreashold = [SELECT Id, Label, ObjectName__c, Fieldset__c, ConfidenceThreashold__c, FlaggingThreashold__c FROM Merge_Field_Setting__mdt where ObjectName__c =:sObjName ];

       
            System.debug('CONFIDENCE TOP: ' + top.confidence);
        if(!lstThreashold.isEmpty()) {
            //Call the merge functionality if the master record confidence level is > confidence threshold.
            if(top.confidence >= lstThreashold[0].ConfidenceThreashold__c) {
              
                return mergeRecords(top.record, obj);
            }
            
            //Mark as possible duplicate
            else if(top.confidence >= lstThreashold[0].FlaggingThreashold__c){
                
                 return flag(top.record);
            }
        }
        //If no configuration defined on the custom meta data then return the object for creation. 
        return obj;
    }
    
    /**
    *Search method responsible for checking for the duplicate record.
    * Datacloud.FindDuplicates is used for searching for the duplicate record based on the duplicate rule 
    * defined on the system.
    * @Param :o [Takes the Sobject for searching for the duplicate record.]
    * @return [SearchResult] searchResult is a wrapper class which holds the reference to the SObject and confidence level.
    * @author Stian Ruud Schikora
    */
    public static SearchResult[] search(sObject o) {

        SearchResult[] result = new SearchResult[]{};
        // Datacloud.FindDuplicates API used for checking for the duplicated record.
        for(Datacloud.FindDuplicatesResult findDupeResult : Datacloud.FindDuplicates.findDuplicates(new List<sObject>{o})) {
            for(Datacloud.DuplicateResult dupeResult : findDupeResult.getDuplicateResults()) {
                for(Datacloud.MatchResult matchResult : dupeResult.getMatchResults()) {
                    for(Datacloud.MatchRecord matchRecord : matchResult.getMatchRecords()) {
                        //If it found the match then creates the object with matching record with its confidence level.
                        System.debug(matchRecord.getFieldDiffs());
                        result.add(new SearchResult(
                            matchRecord.getRecord(), matchRecord.getMatchConfidence()
                        ));
                        
                    }
                }
            }
        }
        
        return result;
    }
    
    /**
   * mergeRecords method responsible for merging the information from input sobject record with the existing  Master  record. 
   * Based on the object name method will query the custom metadata and reads the fields to be considered on the merge 
   * functionality. 
   * @Param :master [Existing record for which the information to be merged.]
   * @Param :record [Sobject record to be merged with the existing master object.]
   * @return:Returns the merged record.
   * @author Stian Ruud Schikora
   */

    @testVisible
    private static sObject mergeRecords(sObject master, sObject record){        
        //Identify Object used on  Data manager.    
        
        Id myId = String.valueOf(master.get('Id'));
        String sObjName = myId.getSObjectType().getDescribe().getName();
        
        //Check for the custom setting with the Object name.
        List<Merge_Field_Setting__mdt> lstMergeSettingList = [SELECT Id, NamespacePrefix, Label, QualifiedApiName, ObjectName__c, Fieldset__c, MasterLabel, Language, DeveloperName FROM Merge_Field_Setting__mdt where ObjectName__c = :sObjName];
        //Checks for the existence of configuration on the custom setting.
        if(lstMergeSettingList.isEmpty()) {
            // If configuration does not exist then return the existing record.
            return master;
        }
        else {
            
            // Get the description of the object to be merged. 
            
            Schema.SObjectType objSobjectType = Schema.getGlobalDescribe().get(sObjName);
            Schema.DescribeSObjectResult objSobjectResult = objSobjectType.getDescribe();

            //get the API name of the columns to be merged. 
            
            String columns  = lstMergeSettingList[0].Fieldset__c;
            List<String> mergeColumnSet = columns.split(',');
            
            for(String item : mergeColumnSet) {
                //
                //Checks if the source record field has any value or not ?
                if(record.get(item) != null) {
                    master.put(item,record.get(item)); 
                }
            }
        }
        return master; //Return merged master
    }
    
    /**
   * flag method responsible for flagging the record for manual duplicate check. 
   * @Param :objrecord [Record for which the ManualDuplicateCheck__c to be set to true.]
   * @return:Returns the updated record.
   * @author Stian Ruud Schikora
   */
    @testVisible
    private static Sobject flag(sObject objrecord) {
        //Flag as possible duplicate, so it can be handled manually
        objrecord.put('ManualDuplicateCheck__c',true);
        return objrecord;
    }
    
   /**
   * SearchResult wrapper class implements comparable interface.
   * Class contains the following fields record of type Sobject and confidence of type double.
   * @author Stian Ruud Schikora
   */
    public class SearchResult implements Comparable {
        
        public final sObject record;
        public final Double confidence;
        
        public SearchResult(sObject record, Double confidence){
            this.record = record; this.confidence = confidence;
        }
        //Below method implements sort functionality.
        public Integer compareTo(Object compareTo){
            SearchResult other = (SearchResult)compareTo;
            return (this.confidence == other.confidence ? 0 : 
                    (this.confidence > other.confidence ? 1 : -1));
        }
    }
}
