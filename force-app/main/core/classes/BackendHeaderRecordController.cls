public with sharing class BackendHeaderRecordController {

/*****  Datos  *****/
  public String csObjectName{get;set;}
  private Boolean queryRecordNotDone = true;
  public SObject cRecord{get{
      if (queryRecordNotDone && cRecord !=null && cRecord.Id != null ) {
        Id recordId = cRecord.Id;
        Set<String> setPicklistFields = new Set<String>();
        List<String> listToDescribe = new List<String>{csObjectName};
        Schema.DescribeSObjectResult objectDescribe = Schema.describeSObjects(listToDescribe)[0];
        Set<String> picklistTypes = new Set<String>{'PICKLIST','MULTIPICKLIST'};
        String query = 'SELECT Id, Name ';
        Set<String> fieldsLowerCase = new Set<String>();
        Set<String> fields = new Set<String>();
        for(HeaderColumn c: columns){
          if(c.Name != 'Name' && c.Name != 'Id' && !fieldsLowerCase.contains(c.Name.toLowercase())){
            String auxName = c.Name.deleteWhitespace().toLowercase();
            if(objectDescribe.fields.getMap().containskey(auxName) && picklistTypes.contains(objectDescribe.fields.getMap().get(auxName).getDescribe().getType().name())){
              fields.add('toLabel('  + c.Name + ')');
              //query += ', toLabel('  + c.Name + ')';
            }else{
              fields.add(c.Name);
              //query += ', '  + c.Name;
            }           
            if(c.Name.contains('__r')){
              fields.add(c.Name.substring(0, c.Name.indexOf('__r') ) + '__c');
              //query += ', ' + c.Name.substring(0, c.Name.indexOf('__r') ) + '__c';
            }
            fieldsLowerCase.contains(c.Name.toLowercase());
          }
        }
        query += !fields.isEmpty() ?  ', ' + String.join(new List<String>(fields), ',') : '';
        query += ' FROM ' + csObjectName;
        query += ' WHERE Id = : recordId ';
        cRecord = Database.query(query)[0];
        queryRecordNotDone = false;
      }
      return cRecord;
    }set;}

/*****  Fieldset  *****/
  public class HeaderColumn {
    public String id{get;set;}
    public String Type{get;set;}
    public String Name{get;set;}
    public String Label{get;set;}
    public String Href{get;set;}
    public Boolean getIsCrossFormula(){return (Name.countMatches('.') == 0 || (Name.countMatches('.') ==  1 && Name.endsWith('.Name'))) ? false : true;}
  }
  public String cFieldset{get;set;}

  private Map<String, Schema.SObjectField> objectFieldMap { get {
    if ( objectFieldMap == null && !String.isBlank(csObjectName) ) {
      Schema.DescribeSObjectResult[] describeObjects = Schema.describeSObjects(  new List<String>{csObjectName} );
      if ( describeObjects.size() > 0 ) {
        objectFieldMap = describeObjects.get(0).fields.getMap();
      }
    }
    return objectFieldMap;
  } set;}

  public List<HeaderColumn> columns { get {
      if ( columns == null ) {
        if ( !String.isBlank(cFieldset)  ) {
          if ( !cFieldset.startsWith('[') ) {
            cFieldset = '[' + cFieldset.replace('\'', '"') + ']';
          }

          try {
            columns = (List<BackendHeaderRecordController.HeaderColumn>) JSON.deserialize( cFieldset, List<BackendHeaderRecordController.HeaderColumn>.class );
          } catch( JSONException e ) {
              system.debug(LoggingLevel.ERROR, 'INVALID JSON: ' + cFieldset );
              return null;       
          }
          // Rellenar los Labels y Types Nulos
          if ( objectFieldMap != null ) {
            for ( Integer i = 0; i < columns.size() ; i++ ) {
              HeaderColumn c = columns[i];
              //si tiene campo por relacion tomo lo anterior al punto nomas
              String apiName = c.Name.indexOf('.') > 0 ? c.Name.substring(0,c.Name.indexOf('.')) : c.Name;
              //si es un campo custom con __r lo cambio por __c
              if(apiName.indexOf('__r') > 0){
                apiName = apiName.substring(0, apiName.indexOf('__r') ) + '__c';
              //si es un campo standard y no tien el id al
              }else if(!apiName.contains('__c') && c.Name.contains('.') ){
                apiName += 'id';
              }
              Schema.DescribeFieldResult fieldDescribe = objectFieldMap.get(apiName).getDescribe();
              if(objectFieldMap.containsKey(apiName)){                
                if(!fieldDescribe.isAccessible()){
                  columns.remove(i);
                  i--;
                }else if(c.Label == null || c.Type == null){
                  if(apiName.toLowerCase() == 'recordtypeid' || apiName.toLowerCase().contains('recordtype.id')){
                    c.Type = 'string';
                  }
                  if(c.Label == null){
                    c.Label = fieldDescribe.getLabel();
                  }
                  if(c.Type == null){
                    c.Type = fieldDescribe.getType().name();
                  }
                }
              }
            }
          }


        }
      }
      return columns;
    } set;
  }

  @RemoteAction
  public static RemoteActionResult deleteRecord( Id recordId ){
    RemoteActionResult result = new RemoteActionResult();

    try{
        if ( recordId == null ) {          
          result.addMessage(new RemoteActionResult.RemoteActionMessage( ApexPages.Severity.ERROR, String.format(Label.RequiredArgument, new String[]{'recordId'} ) ) );        
        } else {
          sobjectType sobjectType = recordId.getSobjectType();
          SObject record = sobjectType.newSObject();
          record.id = recordId;

          if(SecurityUtils.checkSObjectIsDeletable(sobjectType)){
            delete record;
          }else{
            throw new FieloPLT.FieloException(Label.CannotDeleteRecords);
          }
          // TODO cambiar label
          result.addMessage(new RemoteActionResult.RemoteActionMessage( ApexPages.Severity.Confirm, label.RecordDeletedSuccessfully) );
          //if ( String.isBlank(retUrl)  ) {
            result.redirectURL = '/' + sobjectType.getDescribe().getKeyPrefix();
          //} else {
          //  result.redirectURL = retUrl;
          //}
        }
    }catch(Exception e){
        result.addMessage(new RemoteActionResult.RemoteActionMessage(e));
    }
    return result;
  }

}