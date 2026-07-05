output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}

output "talosconfig" {
  value       = file(module.talos.path_to_talosconfig_file)
  sensitive   = true
  description = "Der rohe Inhalt der talosconfig zur direkten Nutzung."
}