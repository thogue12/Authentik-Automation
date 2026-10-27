output "id" {
  description = "ID of the application."
  value       = authentik_application.this.id
}

output "slug" {
  description = "Slug of the application."
  value       = authentik_application.this.slug
}

output "uuid" {
  description = "Generated UUID of the application (used as policy binding target)."
  value       = authentik_application.this.uuid
}

output "name" {
  description = "Name of the application."
  value       = authentik_application.this.name
}
