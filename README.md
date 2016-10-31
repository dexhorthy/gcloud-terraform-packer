Google Compute Autoscaling with Terraform and Packer
==========

Using Terraform and Packer to bootstrap a google cloud autoscaling group.





Running the project
-------------------

#### Prerequistes

- [Install Packer](https://www.packer.io/intro/getting-started/setup.html)
- [Install Terraform](https://www.terraform.io/intro/getting-started/install.html)
- Log into the Google Cloud console and [Create Google Account JSON](https://console.developers.google.com/apis/dashboard) and place the file in ~/.gcloud/account.json
- Generate an ssh keypair at `~/.ssh/gcloud_id_rsa` & `~/.ssh/gcloud_id_rsa.pub`
- [Install gcloud CLI tools](https://cloud.google.com/sdk/gcloud/#downloading_gcloud), ensure the `gcloud` executable is on your path, and log in using `gcloud auth login`
- You will need to enable several Google Cloud APIs to run the project.
  You can either set these up ahead of time, or enable them as you go.
  If a terraform operation fails because an API has not been enabled,
  the error output will include a link to enable the API in a browser.
  If, however, you want to set them up ahead of time, you can navigate to the APIs section of the console and enable:
    - Google Compute Engine API
    - Google Cloud Storage API
    - Google Compute Engine Instance Group Manager API
    - Google Compute Engine Instance Group Updater API
    - Google Compute Engine Instance Groups API

#### tl;dr

The walkthrough below is pretty involved. If you want to jump right in:

```sh
cp terraform.tfvars.example terraform.tfvars
packer build packer.json # outputs image_name
terraform apply -var base_image=<image_name> # outputs pool_public_ip
curl <pool_public_ip>
./spam.sh <pool_public_ip>
watch -d gcloud compute instances list
```

Clean up with 

```
terraform destroy
gcloud compute images list --regexp packer-tf-demo.* | tail -n +2 | cut -d' ' -f 1 | xargs gcloud compute images delete
```


#### Walkthrough

First, you'll want to copy the example variables file:

```sh
cp terraform.tfvars.example terraform.tfvars
```

If you want to tweak the project name, region, or any paths in `terraform.tfvars`, now is a good time.

Next, Use packer to build a GCE image:

```sh
packer build packer.json
```

You can then verify the created image id using `gcloud`:

```sh
gcloud compute images list
```

You'll want to grab the image name looking like `packer-tf-demo-{{timestamp}}` for use in the next step.

Before running terraform, You may find it helpful to spin up a second terminal and run

```sh
watch -d gcloud compute instances list
```

so you can observe infrastructure changes as they occur.

Once you've set up your instance watch, you're ready to apply your terraform configuration:
If you don't want to pass the image via `-var`, you can also add it to `terraform.tfvars`.

```sh
terraform apply -var base_image=<your_image_id>
```


If you see any error output with regard to APIs not being enabled for a project,
you can follow the url in the output to enable the API, then re-run `terraform apply`.
You may have to do this several times before terraform completes successfully.

Once terraform completes successfully, you should see an IP output as `pool_public_ip` -- 
take note of this for the next step. In your watch command, you should see something like

```
NAME               ZONE           MACHINE_TYPE  PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
tf-demo-demo-2qy2  us-central1-a  f1-micro                   10.128.0.3   146.148.87.56   RUNNING
tf-demo-demo-u4il  us-central1-a  f1-micro                   10.128.0.2   130.211.192.55  RUNNING
```

Our `google_compute_autoscaler` is configured with minimum instance count of two, and a maximum of ten.
The next step is to generate some traffic to trigger scaling of the instance group.

We can test the instance pool with `curl`:

```sh
curl <your_pool_public_ip>
```

And you should see

```
This instance was provisioned by Packer
```

Which is the message we wrote to `/usr/share/nginx/html/index.html` during Packer provisioning.

#### Triggering Autoscaling

Once we've bootstrapped our pool, we'll need to increase cpu load to trigger the autoscaling. Since these
are `f1-micro` instances, we'll be able to trigger scaling just by spamming nginx with lots of traffic.

There's a script provided in `spam.sh` that given the value of `pool_public_ip`, 
will send 10,000 requests to our instance pool using `ab`:

```
./spam.sh <your_pool_public_ip>
```

In the meantime, keep an eye on the output of

```
watch -d gcloud compute instances list
```

You should see at least one additional instance spin up automatically to handle the additional load.
If you're inclined, you can run `spam.sh` a few more times to try and trigger additional instance launches.

Compute Engine Autoscaling is much more aggressive when it comes to launching instances than it is when
cleaning them up when traffic subsides. If you watch the instance list for 10-20 minutes, however, you should
see them eventually spin down to the minimum pool size.


#### Cleaning up

First destroy your terraform infrastructure:

```
terraform destroy
```

Next, get any image ids we created with

```
gcloud compute images list --regexp packer-tf-demo.*
```

and delete them with

```
gcloud compute images delete <image_id>
```

Or, in one line:

```
gcloud compute images list --regexp packer-tf-demo.* | tail -n +2 | cut -d' ' -f 1 | xargs gcloud compute images delete
```


#### Gotchas

1. It seems like the forwarding rule used here is pretty dumb,
   it sometimes routes traffic to hosts that aren't ready yet. There's a short
   period (~ a few seconds) where a host is "Running" but wont serve requests properly. If a `curl`
   request hangs, you're best off killing the request and retrying.

2. As mentioned in *Prerequisites*, you will likely see some errors about needing to enable certain 
  Google Cloud Platform APIs. In general, these can be enabled by navigating to the URL in the error output,
  Enabling the API, and then re-running any failed commands.
