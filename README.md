

# Architecture

For this part, the following architecture is proposed:
-   AWS
-   VPC
-   EKS (with Managed node groups)
-   Helm chart with Horizontal Pod Autoscaler for scalability
-   Load balancing with AWS alb ingress controller


As the idea is to have an automatic scaling system based on resources used, K8s has been selected.

In AWS, there are 3 different scenarios for types of nodes:

-   Managed node groups
-   Self-managed nodes
-   AWS Fargate


Since Fargate is not a standard K8s deployment, it has been removed. Moreover, since the default AWS AMI used for Managed node groups is stable, this option has been selected. The second option is very useful when installing a non-Linux instance, which is not our case.

There are different options for ingress controller that can have a public IP address in AWS:

-   Nginx ingress controller and AWS NLB
-   AWS alb ingress controller, and Loadbalancer service in k8s
-   etc.


The second option has been selected, because:
-   It will distribute traffic between pods (not necessarily ec2 instances)
-   It uses standard Loadbalancer service tag
-   AWS alb ingress controller is opensource and has a rich community

# How-to

## Prerequisite:

> Terraform version ~ v0.14.4
> Helm verion ~ v3.3.4

Be sure the aws config file exists:

    cat ~/.aws/credentials

    [default]
    aws_access_key_id = xxxxxx
    aws_secret_access_key = xxxxxx

and also, aws account id should be placed in aws load balancer service account:

Mac:

    sed -i'.yaml' 's/AWSACCOUNT/xxxxxx/' helm/aws-load-balancer-controller/aws-load-balancer-controller-service-account

Linux:

    sed -i 's/AWSACCOUNT/xxxxxx/' helm/aws-load-balancer-controller/aws-load-balancer-controller-service-account
    mv helm/aws-load-balancer-controller/aws-load-balancer-controller-service-account helm/aws-load-balancer-controller/aws-load-balancer-controller-service-account.yml

## Terraform

This will create VPC and EKS:

    cd terraform;
    terraform init;
    terraform apply

The parameters can be changed based on needs.

## Helm

The default name of the eks cluster is *my-eks-cluster*. In case of change, should be replaced below.

After the deploy is finished, the **~/.kube/config** file should be updated:

    aws eks update-kubeconfig  --name my-eks-cluster


Then, we will install aws load balancer controller:

    cd ../helm
    kubectl apply -f aws-load-balancer-controller/aws-load-balancer-controller-service-account.yaml
    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
    helm repo add eks https://aws.github.io/eks-charts
    helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller --set clusterName=my-eks-cluster --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller -n kube-system

Installing httpbin:

    helm install -f httpbin/values.yaml myhttpbin httpbin

Installing metrics-server:

    kubectl apply -f metrics-server/components.yaml

Checking the status of hpa (horizontal pod autoscaler):

    kubectl describe hpa myhttpbin

Getting the URL of service (take some while for AWS to provision the DNS):

    kubectl get svc myhttpbin | grep myhttpbin | awk {'print $4'}

Load testing the service:

    ab -n 10000 -c 200 $(kubectl get svc myhttpbin | grep myhttpbin | awk {'print $4'})/

and in another shell, checking autoscaling:

    watch -n 1 'kubectl get hpa myhttpbin'

This will show how many replicas are running, like:

    kubectl get hpa myhttpbin
    NAME        REFERENCE              TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
    myhttpbin   Deployment/myhttpbin   64%/50%   1         10        2          13m
