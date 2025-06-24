packer {
  required_plugins {
    amazon = {
      version = ">= 1.3.7"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "nextjs" {
  profile       = "packer-test"
  ami_name      = "practice-aws-2"
  instance_type = "t2.micro"
  region        = "ap-northeast-1"
  ssh_username  = "ec2-user"
  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      virtualization-type = "hvm"
      root-device-type    = "ebs"
    }
    most_recent = true
    owners      = ["137112412989"]
  }
  launch_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 15
    volume_type           = "gp2"
    delete_on_termination = true
  }
  ami_block_device_mappings {
    device_name           = "/dev/xvda"
    volume_size           = 15
    volume_type           = "gp2"
    delete_on_termination = true
  }
}

build {
  name    = "practice-aws"
  sources = ["source.amazon-ebs.nextjs"]

  # nodeとnginxのインストール
  provisioner "shell" {
    inline = [
      "curl -fsSL https://rpm.nodesource.com/setup_22.x | sudo bash -",
      "sudo dnf install -y nodejs",
      "sudo dnf install -y nginx",
      "sudo systemctl enable nginx",
      "sudo systemctl start nginx"
    ]
  }

  # nginxの構成ファイルを追加
  provisioner "file" {
    source      = "../nginx.conf"
    destination = "/tmp/nextjs.conf"
  }

  provisioner "shell" {
    inline = [
      "sudo mv /tmp/nextjs.conf /etc/nginx/conf.d/nextjs.conf",
      "sudo nginx -t",
      "sudo systemctl restart nginx"
    ]
  }

  provisioner "shell" {
    inline = [
      "sudo rm -f /home/ec2-user/app",
      "mkdir -p /home/ec2-user/app",
      "chown ec2-user:ec2-user /home/ec2-user/app"
    ]
  }

  # アプリケーションコードのコピー
  provisioner "file" {
    source      = "../"
    destination = "/home/ec2-user/app"
  }

  # サーバーの起動
  provisioner "shell" {
    inline = [
      "cd /home/ec2-user/app",
      "npm install",
      "chmod +x node_modules/.bin/*",
      "npm run build",
      "chown -R ec2-user:ec2-user /home/ec2-user/app",
    ]
  }
}