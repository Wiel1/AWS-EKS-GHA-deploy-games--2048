

```
name: CI/CD Spring Boot to Azure Kubernetes Service

on: 
  workflow_dispatch:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

permissions:
  id-token: write
  contents: read

jobs:
  test:
    name: Unit Test and SpotBugs
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 17
        uses: actions/setup-java@v3
        with:
          java-version: '17'
          distribution: 'microsoft'
          cache: 'maven'
      ## Unit test and SBOM generation is carried out in 'mvn package', and SpotBugs report is generated in 'mvn site'
      - name: Build with Maven
        run: mvn -B clean package site
      - name: Upload SBOM(Cyclonedx)
        uses: actions/upload-artifact@v3
        with:
          name: bom.json
          path: './target/bom.json'
      - name: Upload SpotBugs Report
        uses: actions/upload-artifact@v3
        with:
          name: spotbugs-site
          path: './target/site/'
  scan:
    name: Scan dependencies with Trivy
    needs: test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3
      - name: Install latest Trivy CLI
        run: |
          wget https://github.com/aquasecurity/trivy/releases/download/v0.41.0/trivy_0.41.0_Linux-64bit.deb
          sudo dpkg -i trivy_0.41.0_Linux-64bit.deb
      - uses: actions/download-artifact@v3
        with:
          name: bom.json
      - name: Run Trivy with SBOM
        run: trivy sbom ./bom.json

  container:
    name: Build container with CNB and push to ACR
    needs: scan
    runs-on: ubuntu-latest

    outputs:
      LOGINSERVER: ${{ steps.image.outputs.LOGINSERVER }}
      IMAGE: ${{ steps.versioning.outputs.IMAGE }}

    steps:
      - uses: actions/checkout@v3

      - name: 'Az CLI Login'
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.CLIENT_ID }}
          tenant-id: ${{ secrets.TENANT_ID }}
          subscription-id: ${{ secrets.SUBSCRIPTION_ID }}

      - name: ACR Login with AZ CLI
        id: image
        run: |
          ACR_JSON=$(az acr login --name acrjay --expose-token)
          TOKEN=$(echo $ACR_JSON | jq -r .accessToken)
          LOGINSERVER=$(echo $ACR_JSON | jq -r .loginServer)
          echo "LOGINSERVER=$LOGINSERVER" >> $GITHUB_ENV
          echo "LOGINSERVER=$LOGINSERVER" >> $GITHUB_OUTPUT
          
          docker login ${LOGINSERVER} --username 00000000-0000-0000-0000-000000000000 --password-stdin <<< $TOKEN

      - name: Install pack CLIs including pack and yq
        uses: buildpacks/github-actions/setup-pack@v5.0.0
        with:
          pack-version: '0.29.0'

      - name: Set the image name and version
        id: versioning
        run: |
          VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          REPO_NAME=${{ github.event.repository.name }}
          echo "IMAGE=$REPO_NAME:$VERSION" >> $GITHUB_ENV
          echo "IMAGE=$REPO_NAME:$VERSION" >> $GITHUB_OUTPUT

      - name: Pack build
        run: |
          pack build ${LOGINSERVER}/${IMAGE} --builder paketobuildpacks/builder:base --buildpack paketo-buildpacks/java-azure --env BP_JVM_VERSION=17 --publish

  deployment:
    name: Deploy image to AKS
    needs: container
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - name: 'Az CLI Login'
        uses: azure/login@v1
        with:
          client-id: ${{ secrets.CLIENT_ID }}
          tenant-id: ${{ secrets.TENANT_ID }}
          subscription-id: ${{ secrets.SUBSCRIPTION_ID }}

      - uses: azure/setup-kubectl@v3
        name: Setup kubectl

      - name: Setup kubelogin
        uses: azure/use-kubelogin@v1
        with:
          kubelogin-version: 'v0.0.29'

      - name: Set AKS context
        id: set-context
        uses: azure/aks-set-context@v3
        with:
          resource-group: 'sandbox-rg'
          cluster-name: 'rbac-cluster'
          admin: 'false'
          use-kubelogin: 'true'

      - name: Deploy image using Kustomize
        env:
          IMAGE: ${{needs.container.outputs.IMAGE}}
          LOGINSERVER: ${{needs.container.outputs.LOGINSERVER}}
        run: |
          curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
          cd k8s
          kustomize edit set image cicd-java=${LOGINSERVER}/${IMAGE}
          kustomize build . | kubectl apply -f -

```

###
###
###
### docker.yaml
```
name: Docker Build
'on':
  workflow_dispatch: {}
  push: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v1
      with:
        fetch-depth: '0'
    - name: Set up QEMU
      uses: docker/setup-qemu-action@v2
    - name: Set up Docker Buildx
      uses: docker/setup-buildx-action@v2
    - name: Login to Docker Hub
      uses: docker/login-action@v2
      with:
        username: ${{ secrets.DOCKERHUB_SAMPLES_USERNAME }}
        password: ${{ secrets.DOCKERHUB_SAMPLES_PASSWORD }}
    - name: Install GitVersion
      uses: gittools/actions/gitversion/setup@v0.9.14
      with:
        versionSpec: 5.x
    - id: determine_version
      name: Determine Version
      uses: gittools/actions/gitversion/execute@v0.9.14
      with:
        additionalArguments: /overrideconfig mode=Mainline
    - name: Install Octopus Deploy CLI
      uses: OctopusDeploy/install-octopus-cli-action@v1
      with:
        version: latest
    - name: Set up JDK 1.17
      uses: actions/setup-java@v2
      with:
        java-version: '17'
        distribution: adopt
    - name: Test
      run: ./mvnw --batch-mode test
      shell: bash
    - if: always()
      name: Report
      uses: dorny/test-reporter@v1
      with:
        name: Maven Tests
        path: target/surefire-reports/*.xml
        reporter: java-junit
        fail-on-error: 'false'
    - name: Build and push
      uses: docker/build-push-action@v3
      with:
        push: true
        tags: octopussamples/randomquotesjava:${{ steps.determine_version.outputs.semVer }}
    - name: Create Octopus Release
      uses: OctopusDeploy/create-release-action@v1.1.1
      with:
        api_key: ${{ secrets.OCTOPUS_API_TOKEN }}
        project: Random Quotes
        server: ${{ secrets.OCTOPUS_SERVER_URL }}
        deploy_to: Dev
        packages: Deploy container to Kubernetes:randomquotes:${{ steps.determine_version.outputs.semVer }}

```

###
```
# The following workflow provides an opinionated template you can customize for your own needs.
#
# If you are not an Octopus user, the "Push to Octopus", "Generate Octopus Deploy build information",
# and "Create Octopus Release" steps can be safely deleted.
#
# To configure Octopus, set the OCTOPUS_API_TOKEN secret to the Octopus API key, and
# set the OCTOPUS_SERVER_URL secret to the Octopus URL.
#
# Double check the "project" and "deploy_to" properties in the "Create Octopus Release" step
# match your Octopus projects and environments.
#
# Get a trial Octopus instance from https://octopus.com/start

name: Java Gradle Build
'on':
  workflow_dispatch: {}
  push: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: '0'
      - name: Install GitVersion
        uses: gittools/actions/gitversion/setup@v0.9.15
        with:
          versionSpec: 5.x
      - id: determine_version
        name: Determine Version
        uses: gittools/actions/gitversion/execute@v0.9.15
        with:
          additionalArguments: /overrideconfig mode=Mainline
      - name: Install Octopus Deploy CLI
        uses: OctopusDeploy/install-octopus-cli-action@v1
        with:
          version: latest
      - name: Set up JDK 1.17
        uses: actions/setup-java@v2
        with:
          java-version: '17'
          distribution: adopt
      - name: List Dependencies
        run: ./gradlew dependencies --console=plain > dependencies.txt
        shell: bash
      - name: Collect Dependencies
        uses: actions/upload-artifact@v2
        with:
          name: Dependencies
          path: dependencies.txt
      - name: Test
        run: ./gradlew check --console=plain
        shell: bash
      - if: always()
        name: Report
        uses: dorny/test-reporter@v1
        with:
          name: Gradle Tests
          path: build/test-results/**/*.xml
          reporter: java-junit
          fail-on-error: 'false'
      - name: Package
        run: ./gradlew clean assemble --console=plain
        shell: bash
      - id: get_artifact
        name: Get Artifact Path
        run: |-
          # Find the largest WAR or JAR, and assume that was what we intended to build.
          echo "::set-output name=artifact::$(find build -type f \( -iname \*.jar -o -iname \*.war \) -printf "%p\n" | sort -n | head -1)"
        shell: bash
      - id: get_artifact_name
        name: Get Artifact Name
        run: |-
          # Get the filename without a path
          path="${{ steps.get_artifact.outputs.artifact }}"
          echo "::set-output name=artifact::${path##*/}"
        shell: bash
      - name: Tag Release
        uses: mathieudutour/github-tag-action@v6.1
        with:
          custom_tag: ${{ steps.determine_version.outputs.semVer }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
      - id: create_release
        name: Create Release
        uses: actions/create-release@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          tag_name: ${{ steps.determine_version.outputs.semVer }}+run${{ github.run_number }}-attempt${{ github.run_attempt }}
          release_name: Release ${{ steps.determine_version.outputs.semVer }} Run ${{ github.run_number }} Attempt ${{ github.run_attempt }}
          draft: 'false'
          prerelease: 'false'
      - name: Upload Release Asset
        uses: actions/upload-release-asset@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          upload_url: ${{ steps.create_release.outputs.upload_url }}
          asset_path: ${{ steps.get_artifact.outputs.artifact }}
          asset_name: ${{ steps.get_artifact_name.outputs.artifact }}
          asset_content_type: application/octet-stream
      - id: get_octopus_artifact
        name: Create Octopus Artifact
        run: |
          # Octopus expects artifacts to have a specific file format
          file="${{ steps.get_artifact.outputs.artifact }}"
          extension="${file##*.}"
          octofile="SampleGradleProject-SpringBoot.${{ steps.determine_version.outputs.semVer }}.${extension}"
          cp ${file} ${octofile}
          echo "::set-output name=artifact::${octofile}"
          # The version used when creating a release is the package id, colon, and version
          octoversion="SampleGradleProject-SpringBoot:${{ steps.determine_version.outputs.semVer }}"
          echo "::set-output name=octoversion::${octoversion}"
        shell: bash
      - name: Push packages to Octopus Deploy
        uses: OctopusDeploy/push-package-action@v2
        env:
          OCTOPUS_API_KEY: ${{ secrets.OCTOPUS_API_TOKEN }}
          OCTOPUS_CLI_SERVER: ${{ secrets.OCTOPUS_SERVER_URL }}
        with:
          packages: ${{ steps.get_octopus_artifact.outputs.artifact }}
          overwrite_mode: OverwriteExisting
      - name: Generate Octopus Deploy build information
        uses: OctopusDeploy/push-build-information-action@v3
        env:
          OCTOPUS_API_KEY: ${{ secrets.OCTOPUS_API_TOKEN }}
          OCTOPUS_URL: ${{ secrets.OCTOPUS_SERVER_URL }}
          OCTOPUS_SPACE: ${{ secrets.OCTOPUS_SPACE }}
        with:
          version: ${{ steps.determine_version.outputs.semVer }}
          packages: SampleGradleProject-SpringBoot
          overwrite_mode: OverwriteExisting
      - name: Create Octopus Release
        uses: OctopusDeploy/create-release-action@v1
        with:
          api_key: ${{ secrets.OCTOPUS_API_TOKEN }}
          project: SampleGradleProject-SpringBoot
          server: ${{ secrets.OCTOPUS_SERVER_URL }}
          deploy_to: Development
          packages: ${{ steps.get_octopus_artifact.outputs.octoversion }}
permissions:
  id-token: write
  checks: write
  contents: write

```
###


```
# For a detailed breakdown of this workflow, see https://octopus.com/docs/guides/deploy-java-app/to-tomcat/using-octopus-onprem-github-builtin
#
# The following workflow provides an opinionated template you can customize for your own needs.
#
# If you are not an Octopus user, the "Push to Octopus", "Generate Octopus Deploy build information",
# and "Create Octopus Release" steps can be safely deleted.
#
# To configure Octopus, set the OCTOPUS_API_TOKEN secret to the Octopus API key, and
# set the OCTOPUS_SERVER_URL secret to the Octopus URL.
#
# Double check the "project" and "deploy_to" properties in the "Create Octopus Release" step
# match your Octopus projects and environments.
#
# Get a trial Octopus instance from https://octopus.com/start

name: Java Maven Build
'on':
  workflow_dispatch: {}
  push: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: '0'
    - name: Install GitVersion
      uses: gittools/actions/gitversion/setup@v0.9.15
      with:
        versionSpec: 5.x
    - id: determine_version
      name: Determine Version
      uses: gittools/actions/gitversion/execute@v0.9.15
      with:
        additionalArguments: /overrideconfig mode=Mainline
    - name: Install Octopus Deploy CLI
      uses: OctopusDeploy/install-octopus-cli-action@v1
      with:
        version: latest
    - name: Set up JDK 1.17
      uses: actions/setup-java@v2
      with:
        java-version: '17'
        distribution: adopt
    - name: Set Version
      run: ./mvnw --batch-mode versions:set -DnewVersion=${{ steps.determine_version.outputs.semVer }}
      shell: bash
    - name: List Dependencies
      run: ./mvnw --batch-mode dependency:tree --no-transfer-progress > dependencies.txt
      shell: bash
    - name: Collect Dependencies
      uses: actions/upload-artifact@v2
      with:
        name: Dependencies
        path: dependencies.txt
    - name: List Dependency Updates
      run: ./mvnw --batch-mode versions:display-dependency-updates > dependencyUpdates.txt
      shell: bash
    - name: Collect Dependency Updates
      uses: actions/upload-artifact@v2
      with:
        name: Dependencies Updates
        path: dependencyUpdates.txt
    - name: Test
      run: ./mvnw --batch-mode test
      shell: bash
    - if: always()
      name: Report
      uses: dorny/test-reporter@v1
      with:
        name: Maven Tests
        path: target/surefire-reports/*.xml
        reporter: java-junit
        fail-on-error: 'false'
    - name: Package
      run: ./mvnw --batch-mode -DskipTests=true package
      shell: bash
    - id: get_artifact
      name: Get Artifact Path
      run: |-
        # Find the largest WAR or JAR, and assume that was what we intended to build.
        echo "::set-output name=artifact::$(find target -type f \( -iname \*.jar -o -iname \*.war \) -printf "%p\n" | sort -n | head -1)"
      shell: bash
    - id: get_artifact_name
      name: Get Artifact Name
      run: |-
        # Get the filename without a path
        path="${{ steps.get_artifact.outputs.artifact }}"
        echo "::set-output name=artifact::${path##*/}"
      shell: bash
    - name: Tag Release
      uses: mathieudutour/github-tag-action@v6.1
      with:
        custom_tag: ${{ steps.determine_version.outputs.semVer }}
        github_token: ${{ secrets.GITHUB_TOKEN }}
    - id: create_release
      name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.determine_version.outputs.semVer }}+run${{ github.run_number }}-attempt${{ github.run_attempt }}
        release_name: Release ${{ steps.determine_version.outputs.semVer }} Run ${{ github.run_number }} Attempt ${{ github.run_attempt }}
        draft: ${{ github.ref == 'refs/heads/master' && 'false' || 'true' }}
        name: ${{ github.ref == 'refs/heads/master' && 'false' || 'true' }}
    - name: Upload Release Asset
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.determine_version.outputs.semVer }}+run${{ github.run_number }}-attempt${{ github.run_attempt }}
        files: ${{ steps.get_artifact.outputs.artifact }}
    - id: get_octopus_artifact
      name: Create Octopus Artifact
      run: |-
        # Octopus expects artifacts to have a specific file format
        file="${{ steps.get_artifact.outputs.artifact }}"
        extension="${file##*.}"
        octofile="RandomQuotes-Java.${{ steps.determine_version.outputs.semVer }}.${extension}"
        cp ${file} ${octofile}
        echo "::set-output name=artifact::${octofile}"
        # The version used when creating a release is the package id, colon, and version
        octoversion="RandomQuotes-Java:${{ steps.determine_version.outputs.semVer }}"
        echo "::set-output name=octoversion::${octoversion}"
        ls -la
      shell: bash
    - name: Push packages to Octopus Deploy
      uses: OctopusDeploy/push-package-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.OCTOPUS_SPACE }}
      with:
        packages: ${{ steps.get_octopus_artifact.outputs.artifact }}
        overwrite_mode: OverwriteExisting
    - name: Generate Octopus Deploy build information
      uses: OctopusDeploy/push-build-information-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.OCTOPUS_SPACE }}
      with:
        version: ${{ steps.determine_version.outputs.semVer }}
        packages: RandomQuotes-Java
        overwrite_mode: OverwriteExisting
    - name: Create Octopus Release
      uses: OctopusDeploy/create-release-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.OCTOPUS_SPACE }}
      with:
        project: RandomQuotes-Java
        packages: ${{ steps.get_octopus_artifact.outputs.octoversion }}
permissions:
  id-token: write
  checks: write
  contents: write

```
###
###
###
```
# For a detailed breakdown of this workflow, see https://octopus.com/docs/guides/deploy-java-app/to-tomcat/using-octopus-onprem-github-builtin
#
# The following workflow provides an opinionated template you can customize for your own needs.
#
# If you are not an Octopus user, the "Push to Octopus", "Generate Octopus Deploy build information",
# and "Create Octopus Release" steps can be safely deleted.
#
# To configure Octopus, set the OCTOPUS_API_TOKEN secret to the Octopus API key, and
# set the OCTOPUS_SERVER_URL secret to the Octopus URL.
#
# Double check the "project" and "deploy_to" properties in the "Create Octopus Release" step
# match your Octopus projects and environments.
#
# Get a trial Octopus instance from https://octopus.com/start

name: Samples Java Maven Build
'on':
  workflow_dispatch: {}
  push: {}
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
      with:
        fetch-depth: '0'
    - name: Install GitVersion
      uses: gittools/actions/gitversion/setup@v0.9.15
      with:
        versionSpec: 5.x
    - id: determine_version
      name: Determine Version
      uses: gittools/actions/gitversion/execute@v0.9.15
      with:
        additionalArguments: /overrideconfig mode=Mainline
    - name: Install Octopus Deploy CLI
      uses: OctopusDeploy/install-octopus-cli-action@v1
      with:
        version: latest
    - name: Set up JDK 1.17
      uses: actions/setup-java@v2
      with:
        java-version: '17'
        distribution: adopt
    - name: Set Version
      run: ./mvnw --batch-mode versions:set -DnewVersion=${{ steps.determine_version.outputs.semVer }}
      shell: bash
    - name: List Dependencies
      run: ./mvnw --batch-mode dependency:tree --no-transfer-progress > dependencies.txt
      shell: bash
    - name: Collect Dependencies
      uses: actions/upload-artifact@v2
      with:
        name: Dependencies
        path: dependencies.txt
    - name: List Dependency Updates
      run: ./mvnw --batch-mode versions:display-dependency-updates > dependencyUpdates.txt
      shell: bash
    - name: Collect Dependency Updates
      uses: actions/upload-artifact@v2
      with:
        name: Dependencies Updates
        path: dependencyUpdates.txt
    - name: Test
      run: ./mvnw --batch-mode test
      shell: bash
    - if: always()
      name: Report
      uses: dorny/test-reporter@v1
      with:
        name: Maven Tests
        path: target/surefire-reports/*.xml
        reporter: java-junit
        fail-on-error: 'false'
    - name: Package
      run: ./mvnw --batch-mode -DskipTests=true package
      shell: bash
    - id: get_artifact
      name: Get Artifact Path
      run: |-
        # Find the largest WAR or JAR, and assume that was what we intended to build.
        echo "::set-output name=artifact::$(find target -type f \( -iname \*.jar -o -iname \*.war \) -printf "%p\n" | sort -n | head -1)"
      shell: bash
    - id: get_artifact_name
      name: Get Artifact Name
      run: |-
        # Get the filename without a path
        path="${{ steps.get_artifact.outputs.artifact }}"
        echo "::set-output name=artifact::${path##*/}"
      shell: bash
    - name: Tag Release
      uses: mathieudutour/github-tag-action@v6.1
      with:
        custom_tag: ${{ steps.determine_version.outputs.semVer }}
        github_token: ${{ secrets.GITHUB_TOKEN }}
    - id: create_release
      name: Create Release
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.determine_version.outputs.semVer }}+run${{ github.run_number }}-attempt${{ github.run_attempt }}
        release_name: Release ${{ steps.determine_version.outputs.semVer }} Run ${{ github.run_number }} Attempt ${{ github.run_attempt }}
        draft: ${{ github.ref == 'refs/heads/master' && 'false' || 'true' }}
        name: ${{ github.ref == 'refs/heads/master' && 'false' || 'true' }}
    - name: Upload Release Asset
      uses: softprops/action-gh-release@v1
      with:
        tag_name: ${{ steps.determine_version.outputs.semVer }}+run${{ github.run_number }}-attempt${{ github.run_attempt }}
        files: ${{ steps.get_artifact.outputs.artifact }}
    - id: get_octopus_artifact
      name: Create Octopus Artifact
      run: |-
        # Octopus expects artifacts to have a specific file format
        file="${{ steps.get_artifact.outputs.artifact }}"
        extension="${file##*.}"
        octofile="RandomQuotes-Java.${{ steps.determine_version.outputs.semVer }}.${extension}"
        cp ${file} ${octofile}
        echo "::set-output name=artifact::${octofile}"
        # The version used when creating a release is the package id, colon, and version
        octoversion="RandomQuotes-Java:${{ steps.determine_version.outputs.semVer }}"
        echo "::set-output name=octoversion::${octoversion}"
        ls -la
      shell: bash
    - name: Push packages to Octopus Deploy
      uses: OctopusDeploy/push-package-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.SAMPLES_OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.SAMPLES_OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.SAMPLES_OCTOPUS_SPACE }}
      with:
        packages: ${{ steps.get_octopus_artifact.outputs.artifact }}
        overwrite_mode: OverwriteExisting
    - name: Generate Octopus Deploy build information
      uses: OctopusDeploy/push-build-information-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.SAMPLES_OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.SAMPLES_OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.SAMPLES_OCTOPUS_SPACE }}
      with:
        version: ${{ steps.determine_version.outputs.semVer }}
        packages: RandomQuotes-Java
        overwrite_mode: OverwriteExisting
    - name: Create Octopus Release
      uses: OctopusDeploy/create-release-action@v3
      env:
        OCTOPUS_API_KEY: ${{ secrets.SAMPLES_OCTOPUS_API_TOKEN }}
        OCTOPUS_URL: ${{ secrets.SAMPLES_OCTOPUS_SERVER_URL }}
        OCTOPUS_SPACE: ${{ secrets.SAMPLES_OCTOPUS_SPACE }}
      with:
        project: Random Quotes Java
        packages: ${{ steps.get_octopus_artifact.outputs.octoversion }}
permissions:
  id-token: write
  checks: write
  contents: write

```
