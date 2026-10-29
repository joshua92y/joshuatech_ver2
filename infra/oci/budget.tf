# Budgets (T010): 월 35(통화는 테넌시 rate card = SGD, 속성 없음) + 알림 규칙 4(ACTUAL 10/50/100 % · FORECAST 100 %).
# 대상 = 루트 컴파트먼트(테넌시) 전체. 이름은 §0 이름 예외 패턴(joshuatech-*).
# 수신 이메일은 저장소에 적지 않는다 — 변수 budget_alert_email(기본값 없음)을 운영자가 -var 또는 *.tfvars(.gitignore)로 넘긴다.

variable "budget_alert_email" {
  type        = string
  description = "예산 알림 수신 이메일(쉼표·세미콜론·공백 구분으로 여러 개 가능). 기본값 없음 — 운영자가 -var 'budget_alert_email=…' 또는 tfvars로 제공한다."
  sensitive   = true

  validation {
    condition     = can(regex("^[^@\\s,;]+@[^@\\s,;]+\\.[^@\\s,;]+([,; ]+[^@\\s,;]+@[^@\\s,;]+\\.[^@\\s,;]+)*$", var.budget_alert_email))
    error_message = "budget_alert_email must be one or more e-mail addresses separated by comma, semicolon, or space."
  }
}

resource "oci_budget_budget" "tenancy" {
  compartment_id = var.compartment_ocid
  display_name   = "joshuatech-budget"
  description    = "Monthly budget for the whole tenancy (root compartment): 35 in the tenancy currency"
  amount         = 35
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.compartment_ocid]
}

locals {
  budget_alerts = {
    actual-10    = { type = "ACTUAL", threshold = 10 }
    actual-50    = { type = "ACTUAL", threshold = 50 }
    actual-100   = { type = "ACTUAL", threshold = 100 }
    forecast-100 = { type = "FORECAST", threshold = 100 }
  }
}

resource "oci_budget_alert_rule" "tenancy" {
  for_each = local.budget_alerts

  budget_id      = oci_budget_budget.tenancy.id
  display_name   = "joshuatech-budget-${each.key}"
  description    = "${each.value.type} spend reaches ${each.value.threshold}% of the monthly budget"
  type           = each.value.type
  threshold      = each.value.threshold
  threshold_type = "PERCENTAGE"
  recipients     = var.budget_alert_email
  message        = "joshuatech OCI budget: ${each.value.type} spend has reached ${each.value.threshold}% of the monthly amount."
}
