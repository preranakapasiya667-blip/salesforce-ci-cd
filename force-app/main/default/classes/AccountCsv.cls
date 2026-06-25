/**
* @File Name : AccountCsv.cls
* @Description :
* @Author :
* @Last Modified By :
* @Last Modified On : December 3, 2025
* @Modification Log :
*==============================================================================
* Ver | Date | Author | Modification
*==============================================================================
* 1.0 | December 3, 2025 |   | Initial Version
**/

public class AccountCsv {
	@AuraEnabled
	public static void createAccoutcsv(List<Account> accountList){
		
		Schema.FieldSet fieldSet = Schema.SObjectType.Account.FieldSets.Account_field_Set;

		List<String> csvHeaders = new List<String>();
		for(Schema.FieldSetMember f : fieldSet.getFields()){
			csvHeaders.add(f.getFieldPath());
		}
		String headerRow = String.join(csvHeaders, ',') + '\n';

		for(Account acc : accountList){
			List<String> rowValues = new List<String>();
			for(String field : csvHeaders){
				Object value = acc.get(field);
				rowValues.add(String.valueOf(value));
			}
			String rowData = String.join(rowValues, ',') + '\n';
			String csvFile = headerRow + rowData;
			Blob csvBlob = Blob.valueOf(csvFile);
			
			ContentVersion cv = new ContentVersion();
			cv.Title = 'Account_Data_' + acc.Name + '_' + Date.today();
			cv.PathOnClient = acc.Name + '.csv';
			cv.VersionData = csvBlob;
			cv.IsMajorVersion = true;
			insert cv;

			ContentVersion contentVer = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
			ContentDocumentLink link = new ContentDocumentLink();
			link.ContentDocumentId = contentVer.ContentDocumentId;
			link.LinkedEntityId = acc.Id;
			link.ShareType = 'V'; 
			link.Visibility = 'AllUsers'; 
			insert link;
		}
	}

	public static void updateCsv(Map<Id,Account> newMap ,Map<Id,Account> oldMap){
		Schema.FieldSet fieldSet = Schema.SObjectType.Account.FieldSets.Account_field_Set;

		List<String> csvHeaders = new List<String>();
		for(Schema.FieldSetMember f : fieldSet.getFields()){
			csvHeaders.add(f.getFieldPath());
		}
		List<ContentDocumentLink> linkList = [SELECT Id, LinkedEntityId, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN : newMap.keySet()];

        Map<String,ContentVersion> fileMap = new Map<String,ContentVersion>();
		Map<String,String> linkMap = new Map<String,String>();
		for(ContentDocumentLink link : linkList){
			linkMap.put(link.ContentDocumentId,link.LinkedEntityId);
		}

		List<ContentVersion> cvList = [SELECT Id, ContentDocumentId, VersionData ,PathOnClient,Title
							FROM ContentVersion  WHERE ContentDocumentId IN : linkMap.keySet()];
		for(ContentVersion cv : cvList){
			fileMap.put(linkMap.get(cv.ContentDocumentId),cv);
		}
		System.debug('fileMap---'+fileMap);

		for(Id accId : newMap.KeySet()){
			Account accnewRec = newMap.get(accId);
			Account accOldRec = oldMap.get(accId);
			Map<String,String> updatedValue = new Map<String,String>();
			List<String> fieldNames = new List<String>();
			List<String> fieldValues = new List<String>();
			for(String field : csvHeaders){
				if(String.valueOf(accnewRec.get(field)) != String.valueOf(accOldRec.get(field))){
					updatedValue.put(field,String.valueOf(accnewRec.get(field)));
				}
			}
		System.debug('updatedValue---'+updatedValue);

		
		
		String csvContent = fileMap.get(accId).VersionData.toString();
		List<String> csvRows = csvContent.split('\n');
		System.debug('csvRows---'+csvRows);

		List<String> headers = csvRows[0].split(',');
		for(String fieldName : updatedValue.keySet()){
			Integer fieldIndex = headers.indexOf(fieldName);

			if(fieldIndex != -1){
				
			for(Integer i = 1; i < csvRows.size(); i++){
				List<String> columns = csvRows[i].split(',');
				if(columns.size() > fieldIndex ){
					columns[fieldIndex] = updatedValue.get(fieldName); 
					csvRows[i] = String.join(columns, ',');
					break;
				}
			}
		}


		String updatedCsvContent = String.join(csvRows, '\n');
		Blob updatedBlob = Blob.valueOf(updatedCsvContent);

		ContentVersion newCv = new ContentVersion();
		newCv.ContentDocumentId = fileMap.get(accId).ContentDocumentId;
		newCv.VersionData = updatedBlob;
		newCv.PathOnClient = fileMap.get(accId).PathOnClient != null ? fileMap.get(accId).PathOnClient : 'UpdatedAccount.csv';
		newCv.Title = fileMap.get(accId).Title;
		newCv.IsMajorVersion = true;
		insert newCv;

	}
	}
}
}