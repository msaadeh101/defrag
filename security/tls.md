# TLS

## Trust Model

|Component|Purpose|Example| Notes|
|---------|-------|-------|------|
|**Certificate Authority (CA)**| Signes and issues digital certificates to prove identity and establish a trust chain.|**Let's Encrypt** signs a certificate for `example.com`, which browsers recognize as valid, enabling HTTPS.|Public CAs (**Let's Encrypt**, **DigiCert**) are globally trusted. Internal CAs are used for private networks or corporate domains. Their root certs must be added to clients' truststores.|
|**Keystore**|Stores an app's private key and its certificate chain (the app's identity).|A Java web server uses `server.keystore` to store its private key and SSL certificate for `api.company.com`.|Typically a `.jks` or `.p12` file; managed using `keytool` or `openssl`. Protect it carefully, compromising the private key breaks encryption.|
|**Truststore**|Contains the root and intermediate CA certificates that the app trusts.|A microservice's `truststore.jks` includes internal CA roots so it can securely connect to other company services.|Used for verifying peer certificates. Usually separate from the keystore. Misconfigured truststores can block connections.|

### Component Breakdown

- **Keystore** = What you own (private key + cert)
- **Truststore** = Who you trust (valid CA certificates)
- **CA** = Who everyone trusts (signer of truth)

## Steps

1. **Create a Certificate Authority (CA)**
- **Purpose**: You need a trusted authority to sign certificates. Enterprises will use **Let's Encrypt** or similar.

```bash
openssl req -new -x509 \
  -keyout ca.key \
  -out ca.cert \
  -days 3650 \
  -subj "/CN=MyRootCA"
```

- **Result**: You now have a root certificate (`ca.crt`) and private key (`ca.key`). **The root of trust**.

2. **Create a Private Key and Certificate Signing Request (CSR)**
- **Purpose**: Every service (API, App, ingress) needs its own key pair and certificate.

```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout app.key \
  -out app.csr \
  -subj "/CN=myapp.default.svc.cluster.local"
```

- **Result**: Your secret private key (`app.key`) and your certificate request you will send to the CA (`app.csr`) are created.

3. **Sign the CSR with your CA**
- **Purpose**: Have the CA vouch for the app's identity by signing its CSR.

```bash
openssl x509 -req \
  -in app.csr \
  -CA ca.crt -CAkey ca.key \
  -CAcreateserial \
  -out app.crt \
  -days 365
```

- **Result**: `app.crt` is your signed certificate (now trusted by anything that trusts `ca.crt`)

4. **Combine Key + Cert (Application-Specific Formats)**
- Purpose: Different runtimes require cert/private key formats or containers so that they can deploy in the target env.

|Platform|Format|Description|Example/Notes|
|---------|-----|--------|-------------|
|**Java**/**Kafka**|`.jks` (Java Keystore)|Combines private key and signed certificate chain into a single keystore file. Used by Java-based apps (**Spring**, **Kafka brokers**, etc) for TLS comms.|Use `keytool -importkeystore -srckeystore app.p12 -scrstoretype PKCS12 -destkeystore app.jks -deststoretype JKS`. Ensure alias matches the service (`kafka-broker1`).|
|**NGINX**/**Envoy**/**Ingress**|`.crt` + `.key` PEM files.|Separates the public cert and private key into two files. These are often referenced directly in server or proxy configs.|**NGINX**: `ssl_certificate /etc/ssl/certs/server.crt; ssl_certificate_key /etc/ssl/private/server.key`. Restrict permissions to root/nginx user.|
|**Azure App Service**|`.pfx` (PKCS#12)| A single binary bundle containing the private key, certificate, and optional intermediate chain. `.pfx` is the most widely used format in MSFT.|Generate with `openssl pkcs12 -export -out app.pfx -inkey app.key -in app.crt -certfile ca-chain.crt`. Use password protected PFX.|
|K**ubernetes Secret**|Base64 encoded `.crt` + `.key`|Stores certificate and key as Base64 strings in K8 secrets for Pod volume mounting or TLS termination.|Create with `kubectl create secret tls app-tls --cert=server.crt --key=server.key`. Gather from KeyVault and reference in manifests.|

5. **Create a Truststore**
- **Purpose**: If your app makes outgoing HTTPS or SSL connections, it must know which CAs to trust.

```bash
# For Java
keytool -import -alias myCA -file ca.crt \
  -keystore truststore.jks -storepass changeit -noprompt

# Specify in JVM options
-Djavax.net.ssl.trustStore=truststore.jks -Djavax.net.ssl.trustStorePassword=${TRUST_STORE_PASS}
```
- **Result**: Your app can reference the `truststore.jks` for verifying peer certificates. (In K8, usually `ca.crt` mounted using env variable `SSL_CERT_FILE`)

6. **Deploy Artifacts Securely**


|Target	|How to Deploy|	Notes|
|------|------|----|
|**Kubernetes**	|`kubectl create secret tls` or `Opaque` secret	|Don’t bake certs into Docker images.|
|**App Service**/**Cloud Function**	|Upload `.pfx` or `.cer` via cloud CLI	|Securely store keys in **Key Vault**/**Secret Manager**.|
|**Kafka**/**Java App**|	Mount `.jks` files + provide passwords via environment vars|	Avoid committing `.jks` to Git.|

### Summary

|Step|Output|Purpose|Typical Tool|
|----|------|-------|-----------|
|**1. Create CA**|`ca.key`, `ca.cert`|Root of trust|`openssl`|
|**2. Create CSR**|`app.key`, `app.csr`|App identity|`openssl`/`keytool`|
|**3. Sign CSR**|`app.crt`|Signed certificate|`openssl`|
|**4. Convert/Combine**|`.pfx`/`.jks`/`.pem`|Rumtime Format|`openssl`, `keytool`|
|**5. Truststore**|`.jks`/`.pem`|Who to trust| `keytool`, `config`|
|**6. Deploy**|Secrets|Secure injection|`kubectl`, CLI|

## Deep Dive and Practical Notes

### Inside a Certificate

|Field|Meaning|Example|
|----|----|---------|
|**Version**|	X.509 standard version (usually v3)	|`Version: 3`|
|**Serial Number**|	Unique identifier assigned by the CA.|	`0x94ad10f9e7a3e9`|
|**Signature Algorithm**	|Hashing/encryption algorithm used by CA.	|`sha256WithRSAEncryption`|
|**Issuer**|	The CA that signed this cert.|	`CN=MyRootCA, O=Corp Security`|
|**Validity**	|Start and end dates.|	`Not Before: Nov 1 2024` → `Not After : Nov 1 2025`|
|**Subject**	|The entity this certificate represents (your app).	|`CN=myapp.default.svc.cluster.local`|
|**Subject Alternative Name (SAN)**	|Additional valid hostnames/IPs.|	`DNS:myapp, DNS:myapp.svc, IP:10.0.0.15`|
|**Public Key Info**|	Public key corresponding to your private key.|	`RSA (2048 bits)`|
|**Extensions**	|Usage flags like `Digital Signature`, `Key Encipherment`, etc.	|Used by clients to validate intended purpose.|
|**Signature**	|CA’s cryptographic signature verifying certificate authenticity.	|`Signature Algorithm: sha256WithRSAEncryption`|

### Understanding the Trust Chain

When a TLS handshake occurs:
1. The **server** presents its certificate to the client.
2. The **client** checks that certificate against the **CA** certificates in its **truststore**.
3. If the CA is trusted, the client verifies the certificate signature and confirms the **Common Name (CN)** or **Subject Alternative Name (SAN)** matches the hostname.
4. If all checks pass, encrypted communication begins.

- If your service's cert is signed by an inernal CA that the client doesn't recognize, it will result in `SSLHandshakeException`, `x509: certificate signed by unknown authority`.

### Internal vs. Public CAs

|Type|Usage|Pros|Cons|
|--|-----|-----|----|
|**Public CA (Let’s Encrypt, DigiCert)**	|External websites, public APIs|	**Globally trusted**; no need to distribute root certs.	|Can’t issue certs for private cluster hostnames.|
|**Private**/**Internal CA**	|Service-to-service traffic within a company or Kubernetes cluster.|	**Full control**; can issue **wildcard** or **short-lived certs**.|	Clients must explicitly trust your root CA. Manage distribution securely.|

### Certificate Lifetimes and Rotation

|Type|	Typical Lifetime|	Rotation Method|
|-------|--------------|-------------------|
|**Root CA**	|5–10 years	|Manual renewal, rarely rotated.|
|**Intermediate CA**	|1–3 years	|Automated or semi-automated rotation.|
|**Leaf (Service) Certs**|	90 days–1 year	|Automated (e.g., cert-manager, Vault Agent).|

- For **Leaf Certificates**, use cert-manager of `Kind: Certificate`

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-tls
  namespace: default
spec:
  secretName: example-tls-secret
  duration: 90d                  # Certificate lifetime: 90 days
  renewBefore: 30d               # Renew certificate 30 days before expiry
  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always       # Rotate private key on renewal
  dnsNames:
  - example.com
  issuerRef:
    name: letsencrypt-prod       # Issuer for Let's Encrypt or internal CA
    kind: ClusterIssuer

```

- For **CA** or **Intermediate CA Rotation**: Manual intervention is usually required, but you can use `cert-manager` to deploy the new intermediate CA as a k8 secret and then updating the **issuer**, triggering renewel and finally using `cmctl` to manually trigger if needed.

```bash
cmctl renew certificate example-tls -n default
```

### Managing Trust (Ubuntu)

```bash
sudo cp corp-root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

### Verify Certificates

- Always verify your certificates after generation or rotation.

```bash
# Inspect contents
openssl x509 -in app.crt -text -noout

# Validate against CA
openssl verify -CAfile ca.crt app.crt
```

- For Java:

```bash
keytool -list -v -keystore keystore.jks
keytool -list -v -keystore truststore.jks
```

- Check trust chain from within a pod:

```bash
curl -v https://myservice.default.svc.cluster.local --cacert /etc/tls/ca.crt
```

### Common Issues and Troubleshooting

|Symptom|Cause|Fix|
|------|------|----|
| `x509: certificate signed by unknown authority`	|Client doesn’t trust the signing CA.	|Import CA cert into client truststore.|
|`SSLHandshakeException: No subject alternative names present`|	Cert CN/SAN doesn’t match hostname.|	Reissue CSR with correct SANs.|
|`Keystore was tampered with or password incorrect`	|Incorrect keystore password or corrupted JKS.|	Verify password, recreate if needed.|
|`unable to get local issuer certificate`	|Intermediate CA missing in chain.|	Include intermediate CA in certificate chain file.|