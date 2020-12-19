/*
* This is a new Trigger Framework based on Inheritance and Interfaces
* The sole reason is the existing ones either has unused methods to be defined
* or too complex to implement and understand. Hence a class based Trigger Framework
* with meta programming.
* # Author	: Ashis Kumar Maharana
* # Date	: 07/28/2020
*
* The goal is to create abstractions for each trigger event.
* User will create concrete classes for the events they want to use.
* They will register it for the trigger using metadata.
* The run all method will fetch all registered classes with sequence.
* It will run each class, in their given sequence.
*/
public with sharing class TriggerFramework {
    private static final String DEFAULT_CONSTRUCTOR_EXCEPTION = 'Cannot create instance of TriggerFramework without parameters';
    private static final String NO_HANDLERS_EXCEPTION = 'No handlers registered. Check under Trigger Handler custom metadata';
    // private static final String UNSUPPORTED_CONTEXT = 'Handler is configured with wrong trigger context. Check Trigger Handler metadata';
    // holds the name of the sobject for which triggerframework is implemented
    private String runningSObject;
    private Map<String, String[]> registeredContextHandlers;
    private static Map<String, TriggerFramework> frameworksInMemory;

    private TriggerFramework(String sObjectName) {
        this.runningSObject = sObjectName;
        System.debug(
            System.LoggingLevel.INFO,
            '#### TriggerFramework Initiated for ' +
            runningSObject +
            ' ####'
        );
        registeredContextHandlers = getContextWiseHandlerNames();
    }
    // converting to singleton, only one instance runs for a single transaction for a single object, avoiding multiple metadata queries
    public static TriggerFramework getInstance(String sobjectName) {
        if (frameworksInMemory == null) { frameworksInMemory = new Map<String, TriggerFramework>(); }
        if (!frameworksInMemory.containsKey(sobjectName)) { frameworksInMemory.put(sobjectName, new TriggerFramework(sobjectName)); }
        return frameworksInMemory.get(sobjectName);
    }
    /********************************* HELPER METHOD GET_CONTEXT_WISE_HANDLER_NAMES ********************************/
    private Map<String, String[]> getContextWiseHandlerNames() {
        Map<String, String[]> mapOfContextHandlers;
        for (TriggerHandler__mdt eachHandler : [
            SELECT
            Id,
            DeveloperName,
            SObjectName__c,
            ExecutionOrder__c,
            TriggerContext__c
            FROM TriggerHandler__mdt
            ORDER BY ExecutionOrder__c ASC
        ]) {
            if (eachHandler.SObjectName__c <> this.runningSObject) {
                continue;
            }
            if (mapOfContextHandlers == null) {
                mapOfContextHandlers = new Map<String, String[]>();
            }
            if (mapOfContextHandlers.containsKey(eachHandler.TriggerContext__c)) {
                mapOfContextHandlers.get(eachHandler.TriggerContext__c)
                    .add(eachHandler.DeveloperName);
                System.debug(
                    System.LoggingLevel.INFO,
                    '#### Found Handler ' +
                    eachHandler.DeveloperName +
                    ' for context ' +
                    eachHandler.TriggerContext__c +
                    ' ####'
                );
            } else {
                mapOfContextHandlers.put(
                    eachHandler.TriggerContext__c,
                    new List<String>{ eachHandler.DeveloperName }
                );
                System.debug(
                    System.LoggingLevel.INFO,
                    '#### Found Handler ' +
                    eachHandler.DeveloperName +
                    ' for context ' +
                    eachHandler.TriggerContext__c +
                    ' ####'
                );
            }
        }
        if (mapOfContextHandlers == null) {
            System.debug(
                System.LoggingLevel.ERROR,
                '#### No handlers registered. Check under Trigger Handler custom metadata. ####'
            );
            throw new DataNotFoundException(NO_HANDLERS_EXCEPTION);
        }
        return mapOfContextHandlers;
    }
    /******************************************* INITIATE METHOD ****************************************************/
    /*
    * initiate : This is the entry point of framework. It takes the current trigger operation as an parameter
    * 			 and finds all handlers listed for the object, framework is running for. It picks them in the
    * 			 sorted order of their execution, calls the implemented run method in the same sequence.
    */
    public void initiate(System.TriggerOperation context) {
        String[] contextHandlers = this.registeredContextHandlers.get(context.name());
        if (contextHandlers == null) {
            System.debug(
                System.LoggingLevel.INFO,
                '#### Context ' +
                context.name() +
                ' not found under registered context handlers. Skipping execution ####'
            );
            return;
        }
        TriggerContextInterface contextRunner;
        for (String handler : contextHandlers) {
            Type handlerType = Type.forName(handler);
            if (handlerType == null) {
                System.debug(
                    System.LoggingLevel.ERROR,
                    '#### Apex Class ' +
                    handler +
                    ' does not exist. Check under Trigger Handler custom metadata. ####'
                );
                throw new DataNotFoundException(
                    'Apex Class ' +
                    handler +
                    ' does not exist. Check under Trigger Handler custom metadata.'
                );
            }
            contextRunner = (TriggerContextInterface) handlerType.newInstance();
            if (!contextRunner.supports(context)) {
                throw new UnsupportedTriggerContextException(
                	'Expected ' +
                    context.name() +
                    ' for ' +
                    handler +
                    '. Check configuration in Trigger Handler metadata'
                );
            }
            System.debug(
                System.LoggingLevel.INFO,
                '#### Running ' +
                handler +
                ' ####'
            );
            contextRunner.run();
        }
    }
    /********************************* Exceptions **********************************************************************/
    // Exception related to TriggerFramework
    private class DataNotFoundException extends Exception {
    }
    private class CannotCreateInstanceException extends Exception {
    }
    private class UnsupportedTriggerContextException extends Exception {
    }
    /******************************* ALL PUBLIC INTERFACES & ABSTRACT CLASSES ******************************************/
    public interface TriggerContextInterface {
        void run();
        Boolean supports(System.TriggerOperation operation);
    } // to use a single type instead of all public interfaces
    public abstract class BeforeInsertContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.BEFORE_INSERT);
        }
    }
    public abstract class BeforeUpdateContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.AFTER_UPDATE);
        }
    }
    public abstract class BeforeDeleteContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.BEFORE_DELETE);
        }
    }
    public abstract class AfterInsertContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.AFTER_INSERT);
        }
    }
    public abstract class AfterUpdateContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.AFTER_UPDATE);
        }
    }
    public abstract class AfterDeleteContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.AFTER_DELETE);
        }
    }
    public abstract class AfterUndeleteContext implements TriggerContextInterface {
        public Boolean supports(System.TriggerOperation operation) {
            return operation.equals(System.TriggerOperation.AFTER_UNDELETE);
        }
    }
    /******************************************************************************************************************/
}
