# Upgrading PostgreSQL for Auto DevOps

Auto DevOps provides an [in-cluster PostgreSQL database](index.md#postgresql-database-support)
for your application.

The version of the chart used to provision PostgreSQL:

- Is 0.7.1 in GitLab 12.8 and earlier.
- Can be set to from 0.7.1 to 8.2.1 in GitLab 12.9 and later.

GitLab encourages users to GitLab encourages users to migrate their database to the
newer PostgreSQL chart.

This guide provides instructions on how to migrate your PostgreSQL database, which
involves:

1. Taking a database dump of your data.
1. Installing a new PostgreSQL database using the newer version 8.2.1 of the chart
   and removing the old PostgreSQL installation.
1. Restoring the database dump into the new PostgreSQL.

## Prerequisites

1. Install
   [`kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
1. Ensure that you can access your Kubernetes cluster using `kubectl`.
   This varies based on Kubernetes providers.
1. Prepare for downtime. The steps below include taking the application offline
   so that the in-cluster database does not get modified after the database dump is created.

TIP: **Tip:** If you have configured Auto DevOps to have staging,
consider trying out the backup and restore steps on staging first, or
trying this out on a review app.

## Take your application offline

If required, take your application offline to prevent the database from
being modified after the database dump is created.

1. Get the Kubernetes namespace for the environment. It typically looks like `<project-name>-<project-id>-<environment>`.
   In our example, the namespace is called `minimal-ruby-app-4349298-production`.

    ```sh
    $ kubectl get ns

    NAME                                                  STATUS   AGE
    minimal-ruby-app-4349298-production                   Active   7d14h
    ```

1. For ease of use, export the namespace name:

   ```sh
   export APP_NAMESPACE=minimal-ruby-app-4349298-production
   ```

1. Get the deployment name for your application with the following command. In our example, the deployment name is `production`.

    ```sh
    $ kubectl get deployment --namespace "$APP_NAMESPACE"
    NAME                  READY   UP-TO-DATE   AVAILABLE   AGE
    production            2/2     2            2           7d21h
    production-postgres   1/1     1            1           7d21h
    ```

1. To prevent the database from being modified, set replicas to 0 for the deployment with the following command.
   We use the deployment name from the previous step (`deployments/<DEPLOYMENT_NAME>`).

    ```sh
    $ kubectl scale --replicas=0 deployments/production --namespace "$APP_NAMESPACE"
    deployment.extensions/production scaled
    ```

1. You also will need to set replicas to zero for workers if you have any.

## Backup

1. Get the service name for PostgreSQL. The name of the service should end with `-postgres`. In our example the service name is `production-postgres`.

    ```sh
    $ kubectl get svc --namespace "$APP_NAMESPACE"
    NAME                     TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)    AGE
    production-auto-deploy   ClusterIP   10.30.13.90   <none>        5000/TCP   7d14h
    production-postgres      ClusterIP   10.30.4.57    <none>        5432/TCP   7d14h
    ```

1. Get the pod name for PostgreSQL with the following command. In our example, the pod name is `production-postgres-5db86568d7-qxlxv`.

    ```sh
    $ kubectl get pod --namespace "$APP_NAMESPACE" -l app=production-postgres
    NAME                                   READY   STATUS    RESTARTS   AGE
    production-postgres-5db86568d7-qxlxv   1/1     Running   0          7d14h
    ```

1. Connect to the pod with:

    ```sh
    kubectl exec -it production-postgres-5db86568d7-qxlxv --namespace "$APP_NAMESPACE" bash
    ```

1. Once, connected, create a dump file with the following command.

   - `SERVICE_NAME` is the service name obtained in a previous step.
   - `USERNAME` is the username you have configured for PostgreSQL. The default is `user`.
   - `DATABASE_NAME` is usually the environment name.

   - You will be asked for the database password, the default is `testing-password`.

    ```sh
    ## Format is:
    # pg_dump -h SERVICE_NAME -U USERNAME DATABASE_NAME > /tmp/backup.sql

    pg_dump -h production-postgres -U user production > /tmp/backup.sql
    ```

1. Once the backup dump is complete, exit the Kubernetes exec process with `Control-D` or `exit`.

1. Download the dump file with the following command:

    ```sh
    kubectl cp --namespace "$APP_NAMESPACE" production-postgres-5db86568d7-qxlxv:/tmp/backup.sql backup.sql
    ```

## Retain persistent volumes

By default the [persistent
volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
used to store the underlying data for PostgreSQL is marked as `Delete`
when the pods and pod claims that use the volume is deleted.

This is signficant as, when you opt into the newer 8.2.1 PostgreSQL, the older 0.7.1 PostgreSQL is
deleted causing the persistent volumes to be deleted as well.

You can verify this by using the following command:

```sh
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                     STORAGECLASS   REASON   AGE
pvc-0da80c08-5239-11ea-9c8d-42010a8e0096   8Gi        RWO            Delete           Bound    minimal-ruby-app-4349298-staging/staging-postgres         standard                7d22h
pvc-9085e3d3-5239-11ea-9c8d-42010a8e0096   8Gi        RWO            Delete           Bound    minimal-ruby-app-4349298-production/production-postgres   standard                7d22h
```

To retain the persistent volume, even when the older 0.7.1 PostgreSQL is
deleted, we can change the retention policy to `Retain`. In this example, we find
the persistent volume names by looking at the claims names. As we are
interested in keeping the volumes for the staging and production of the
`minimal-ruby-app-4349298` application, the volume names here are
`pvc-0da80c08-5239-11ea-9c8d-42010a8e0096` and `pvc-9085e3d3-5239-11ea-9c8d-42010a8e0096`:

```sh
$ kubectl patch pv  pvc-0da80c08-5239-11ea-9c8d-42010a8e0096 -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
persistentvolume/pvc-0da80c08-5239-11ea-9c8d-42010a8e0096 patched
$ kubectl patch pv  pvc-9085e3d3-5239-11ea-9c8d-42010a8e0096 -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
persistentvolume/pvc-9085e3d3-5239-11ea-9c8d-42010a8e0096 patched
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                                     STORAGECLASS   REASON   AGE
pvc-0da80c08-5239-11ea-9c8d-42010a8e0096   8Gi        RWO            Retain           Bound    minimal-ruby-app-4349298-staging/staging-postgres         standard                7d22h
pvc-9085e3d3-5239-11ea-9c8d-42010a8e0096   8Gi        RWO            Retain           Bound    minimal-ruby-app-4349298-production/production-postgres   standard                7d22h
```

## Install new PostgreSQL

CAUTION: **Caution:** Using the newer version of PostgreSQL will delete
the older 0.7.1 PostgreSQL. To prevent the underlying data from being
deleted, you can choose to retain the [persistent
volume](#retain-persistent-volumes).

TIP: **Tip:** You can also
[scope](../../ci/environments.md#scoping-environments-with-specs) the
`AUTO_DEVOPS_POSTGRES_CHANNEL` and `POSTGRES_VERSION` variables to
specific environments, e.g. `staging`.

1. Set `AUTO_DEVOPS_POSTGRES_CHANNEL` to `2`. This opts into using the
   newer 8.2.1-based PostgreSQL, and removes the older 0.7.1-based
   PostgreSQL.
1. Set `POSTGRES_VERSION` to `9.6.16`. This is the minimum PostgreSQL
   version supported.
1. Set `PRODUCTION_REPLICAS` to `0`. For other environments, use
   `REPLICAS` with an [environment scope](../../ci/environments.md#scoping-environments-with-specs).
1. If you have set the `DB_INITIALIZE` or `DB_MIGRATE` variables, either
   remove the variables, or rename the variables temporarily to
   `XDB_INITIALIZE` or the `XDB_MIGRATE` to effectively disable them.
1. Run a new CI pipeline for the branch. In this case, we run a new CI
   pipeline for `master`.
1. Once the pipeline is successful, your application will now be upgraded
   with the new PostgreSQL installed. There will also be zero replicas
   which means no traffic will be served for your application (to prevent
   new data from coming in).

## Restore

1. Get the pod name for the new PostgreSQL, in our example, the pod name is
   `production-postgresql-0`:

    ```sh
    $ kubectl get pod --namespace "$APP_NAMESPACE" -l app=postgresql
    NAME                      READY   STATUS    RESTARTS   AGE
    production-postgresql-0   1/1     Running   0          19m
    ````

1. Copy the dump file from the backup steps to the pod:

   ```sh
   kubectl cp --namespace "$APP_NAMESPACE" backup.sql production-postgresql-0:/tmp/backup.sql
   ```

1. Connect to the pod:

   ```sh
   kubectl exec -it production-postgresql-0 --namespace "$APP_NAMESPACE" bash
   ```

1. Once connected to the pod, run the following command to restore the database.

   - You will be asked for the database password, the default is `testing-password`.
   - `USERNAME` is the username you have configured for postgres. The default is `user`.
   - `DATABASE_NAME` is usually the environment name.

   ```sh
   ## Format is:
   # psql -U USERNAME -d DATABASE_NAME < /tmp/backup.sql

   psql -U user -d production < /tmp/backup.sql
   ```

1. You can now check that your data restored correctly after the restore
   is complete. You can perform spot checks of your data by using the
   `psql`.

## Reinstate your application

Once you are satisfied the database has been restored, run the following
steps to reinstate your application:

1. Restore the `DB_INITIALIZE` and `DB_MIGRATE` variables, if previously
   removed or disabled.
1. Restore the `PRODUCTION_REPLICAS` or `REPLICAS` variable to its original value.
1. Run a new CI pipeline for the branch. In this case, we run a new CI
   pipeline for `master`. After the pipeline is successful, your
   application should be serving traffic as before.
