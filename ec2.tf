provider "aws" {
  profile    = "myvaibhav"
  region     = "ap-south-1"
}


resource "tls_private_key" "myprivatekey" {
  algorithm   = "RSA"
}




resource "aws_key_pair" "mykey" {
  key_name   = "myterakey"
  public_key = tls_private_key.myprivatekey.public_key_openssh
}



resource "aws_security_group" "mysecgroup" {
  name        = "terasecuritygroup"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-ad6a75c5"

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

tags = {
    Name = "terasecuritygroup"
  }
}





resource  "aws_instance"   "myowninstance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = "myterakey"
  security_groups   =   [ "${aws_security_group.mysecgroup.name}" ]

  tags = {
    Name = "Vaibhavfirstos"
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.myprivatekey.private_key_pem}"
    host     = "${aws_instance.myowninstance.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd php  git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd"
    ]
  }
}



resource "aws_ebs_volume"  "myebsvolume" {
  availability_zone = "${aws_instance.myowninstance.availability_zone}"
  size              = 8

  tags = {
    Name = "teraebsvolume"
  }
}




resource "aws_volume_attachment"  "attachteravolume" {
  device_name = "/dev/sdb"
  volume_id   = "${aws_ebs_volume.myebsvolume.id}"
  instance_id = "${aws_instance.myowninstance.id}"
  force_detach = true
}




resource "null_resource" "nullresource1" {

  depends_on = [
    aws_volume_attachment.attachteravolume,
  ]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.myprivatekey.private_key_pem}"
    host     = "${aws_instance.myowninstance.public_ip}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdb",      
      "sudo  mount /dev/xvdb  /var/www/html",
      "sudo rm -rf  /var/www/html/*",
      "sudo git clone https://github.com/jain-vaibhav2607/myawsrepo.git  /var/www/html/"
    ]
  }
}




resource "aws_s3_bucket" "mys3bucket" {
  bucket = "tera-image-bucket"
  acl    = "public-read"

  tags = {
    Name        = "My bucket"
  }
}



resource "null_resource" "nulllocalresource1" {

  depends_on = [
    aws_s3_bucket.mys3bucket,
  ]

  provisioner "local-exec" {
    command = "git  clone https://github.com/jain-vaibhav2607/s3bucketrepo   BucketImage"
  }
}





resource "aws_s3_bucket_object" "mys3bucketobject" {

depends_on = [
    null_resource.nulllocalresource1,
  ]


  bucket = "${aws_s3_bucket.mys3bucket.bucket}"
  key    = "my-webserver-image.png"
  source = "C:/Users/vaijain/Desktop/myWorkspace/BucketImage/Terraform.png"
  acl = "public-read"
}



locals {
  s3_origin_id = "S3-${aws_s3_bucket.mys3bucket.bucket}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.mys3bucket.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"
  }

  enabled             = true



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
 }


    restrictions {
       geo_restriction {
          restriction_type = "none"
       }
    }


viewer_certificate {
    cloudfront_default_certificate = true
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.myprivatekey.private_key_pem}"
    host     = "${aws_instance.myowninstance.public_ip}"
  }



    provisioner "remote-exec" {
    inline = [
      "sudo su << EOF",
      "echo \"<img src = 'http://${self.domain_name}/${aws_s3_bucket_object.mys3bucketobject.key}'>\"  >>  /var/www/html/index.php",
      "EOF"      
    ]
  }
    
}





resource "null_resource" "nulllocalresource2" {

  depends_on = [
    aws_cloudfront_distribution.s3_distribution,
  ]

  provisioner "local-exec" {
    command = "start chrome  ${aws_instance.myowninstance.public_ip}"
  }
}
