/* Custom WAF Policy to play

Overrides some actions of the Microsoft_BotManagerRuleSet 1.0 rule set
Blocks requests from Greenland, using GeoIP

This Policy is attached to the /secret path of the AppGW.

*/

resource "azurerm_web_application_firewall_policy" "spoke3_appgw" {
  name                = "waf-1"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location

  policy_settings {
    enabled            = true
    mode               = "Prevention"
    request_body_check = false
  }

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
    managed_rule_set {
      type    = "Microsoft_BotManagerRuleSet"
      version = "1.0"

      rule_group_override {
        rule_group_name = "GoodBots"
        rule {
          action  = "Allow"
          enabled = true
          id      = "200100"
        }
        rule {
          action  = "Block"
          enabled = true
          id      = "200200"
        }
      }
      rule_group_override {
        rule_group_name = "UnknownBots"

        rule {
          action  = "Allow"
          enabled = true
          id      = "300500"
        }
      }
    }
  }

  custom_rules {
    action    = "Block"
    enabled   = true
    name      = "BlockNicePlace"
    priority  = 10
    rule_type = "MatchRule"
    match_conditions {
      match_values = [
        "GL",
      ]
      operator = "GeoMatch"
      match_variables {
        variable_name = "RemoteAddr"
      }
    }
  }
}