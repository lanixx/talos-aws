output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}

output "talosconfig_pfad" {
  value       = module.talos.path_to_talosconfig_file
  description = "Der lokale Dateipfad zur generierten talosconfig."
}

output "talosconfig_inhalt" {
  value       = file(module.talos.path_to_talosconfig_file)
  sensitive   = true
  description = "Der rohe Inhalt der talosconfig zur direkten Nutzung."
}