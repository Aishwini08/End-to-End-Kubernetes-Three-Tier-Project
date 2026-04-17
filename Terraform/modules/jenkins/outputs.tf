output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}
