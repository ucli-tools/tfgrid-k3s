# Security Best Practices

This document outlines security best practices for the tfgrid-k3s project, particularly focusing on handling sensitive credentials.

## Handling Sensitive Credentials

The ThreeFold Grid deployment requires a mnemonic phrase for authentication, which is a highly sensitive credential that should be protected.

### Secure Method for Setting Credentials

We recommend using environment variables with shell history protection:

```bash
# This prevents your mnemonic from being stored in shell history
set +o history
export TF_VAR_mnemonic="your_mnemonic_phrase"
set -o history
```

This approach:
- Keeps sensitive information in memory only, not on disk
- Prevents the command from being saved in your shell history
- Automatically works with the OpenTofu/Terraform `-var` mechanism
- Disappears when you close your terminal session

### Verifying Credentials Are Set

To verify your credentials are set (without exposing them):

```bash
# This will show if the variable exists but not its value
env | grep -o TF_VAR_mnemonic
```

If the command returns `TF_VAR_mnemonic`, the variable is set.

### Additional Security Considerations

1. **Avoid storing credentials in files** whenever possible
2. **Never commit credentials to version control**
3. **Use dedicated terminals** for sensitive operations
4. **Clear your variables when done**:
   ```bash
   unset TF_VAR_mnemonic
   ```
5. **Consider SSH agent forwarding** instead of storing keys on deployment servers

## SSH Key Security

The project also uses SSH keys for node authentication. Best practices:

1. **Use strong, passphrase-protected SSH keys**
2. **Rotate keys regularly** for production deployments
3. **Keep private keys secure** and never share them

## Other Security Measures

1. **Keep software updated** - regularly update OpenTofu, Ansible, and system packages
2. **Use firewalls properly** - limit exposure of K3s services
3. **Apply least privilege principle** - minimize permissions throughout your deployment

For more advanced security topics or enterprise deployments, consider dedicated secret management solutions like HashiCorp Vault.
