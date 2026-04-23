import json
from typing import Optional

from botocore.exceptions import ClientError

from dbt_platform_helper.providers.aws.exceptions import AWSException

class StepFunctions:
  
    def __init__(self, sfn_client, application_name: str, env: str):
        self.sfn_client = sfn_client
        self.application_name = application_name
        self.env = env
    
    def find_state_machine_arn(self, job_name: str) -> Optional[str]:
      
      matches: list[str] = []
      paginator = self.sfn_client.get_paginator('list_state_machines')
      
      for page in paginator.paginate():
          for sm in page.get('stateMachines', []):
            arn = sm.get('stateMachineArn')
            tags = self._list_tags(arn)
            if (tags.get('copilot-application') == self.application_name and
                tags.get('copilot-environment') == self.env and
                tags.get('copilot-service') == job_name 
              ):
                matches.append(arn)
                
      if not matches:
          raise StateMachineNotFoundException(self.application_name, self.env, job_name)
      if len(matches) > 1:
          raise multipleStateMachinesFoundException(self.application_name, self.env, job_name, matches)
      return matches[0]          
                    
    def start_execution(self, state_machine_arn: str, name: Optional[str] = None) -> str:
        kwargs = {"stateMachineArn": state_machine_arn}
        if name:
            kwargs["name"] = name
            
        try:
          result = self.sfn_client.start_execution(**kwargs)
          return result
        
        except ClientError as err:
          raise StartExecutionFailedException(state_machine_arn, err.response.get('Error', {}).get('Message', str(err)))
    
    def _list_tags(self, resource_arn: str) -> dict:
      response = self.sfn_client.list_tags_for_resource(resourceArn=resource_arn)
      return {tag['key']: tag['value'] for tag in response.get('tags', [])}
          
class StateMachineNotFoundException(AWSException):
    def __init__(self, application_name: str, environment: str, job_name: str):
        super().__init__(
            f"""No Step Function state machine found for job '{job_name}' """
            f"""in application '{application_name}' environment '{environment}'."""
            
      )

class StartExecutionFailedException(AWSException):
    def __init__(self, state_machine_arn: str, error: str):
        super().__init__(
            f"Failed to start execution for state machine '{state_machine_arn}' with error: {error}"
        )

class MultipleStateMachinesFoundException(AWSException):
    def __init__(self, application_name: str, environment: str, job_name: str, state_machine_arns: list[str]):
        super().__init__(
            f"""Multiple Step Function state machines found for job '{job_name}' """
            f"""in application '{application_name}' environment '{environment}'. """
            f"""Found ARNs: {state_machine_arns}"""
            f""" Not able to determine which one to start."""
        )
  