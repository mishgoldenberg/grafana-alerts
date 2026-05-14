# YES this is the variable you are looking for to add a new system
systems = [
  {
    system_name = "Example System"
    os          = "windows"
    servers = [
      { name = "Example Server Prod", ip = "<ip-address>:<port>", url = "<system-url>" },
      { name = "Example Server Test", ip = "<ip-address>:<port>", url = "<system-test-url>" }
    ]
  },
  {
    system_name = "Example Linux System"
    os          = "linux"
    servers = [
      { name = "Example Linux Server", ip = "<ip-address>:<port>", url = "<system-url>" }
    ]
  }
]

datasource_uid = "<datasource-uid>"

contact_point_name = "<contact-point-name>"

specific_alert_types = {
  "Example System" = {
    "Example Server Prod" = {
      example_service_alert = {
        display_name = "Example Service State"
        description  = "An example specific alert for demonstration. Customize this for your needs."
        summary      = "Example service is not running."
        severity     = "Critical"
        query        = "{\"editorMode\":\"code\",\"expr\":\"windows_service_state{name=\\\"example-service\\\",state=\\\"running\\\",instance=\\\"ip\\\"}\",\"instant\":true,\"intervalMs\":1000,\"legendFormat\":\"__auto\",\"range\":false,\"refId\":\"A\"}"
        expr         = "{\"conditions\":[{\"evaluator\":{\"params\":[1,0],\"type\":\"lt\"},\"operator\":{\"type\":\"and\"},\"query\":{\"params\":[\"A\"]},\"reducer\":{\"params\":[],\"type\":\"last\"},\"type\":\"query\"}],\"dataSource\":\"__expr__\",\"expression\":\"A\",\"hide\":false,\"refId\":\"B\",\"type\":\"classic_conditions\"}"
      }
    }
  }
}
