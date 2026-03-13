using System.Security.Cryptography;
using System.Text;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Auth;

public sealed class LegacyPasswordCryptoService : IPasswordCryptoService
{
    private const string EncryptionKey = "MAKV2SPBNI99212";
    private static readonly byte[] SaltBytes =
    [
        0x49, 0x76, 0x61, 0x6e, 0x20, 0x4d, 0x65, 0x64, 0x76, 0x65, 0x64, 0x65, 0x76
    ];

    public string Encrypt(string plainText)
    {
        var clearBytes = Encoding.Unicode.GetBytes(plainText);
        using var encryptor = Aes.Create();
        using var pdb = new Rfc2898DeriveBytes(EncryptionKey, SaltBytes);
        encryptor.Key = pdb.GetBytes(32);
        encryptor.IV = pdb.GetBytes(16);

        using var ms = new MemoryStream();
        using (var cs = new CryptoStream(ms, encryptor.CreateEncryptor(), CryptoStreamMode.Write))
        {
            cs.Write(clearBytes, 0, clearBytes.Length);
        }

        return Convert.ToBase64String(ms.ToArray());
    }

    public string? TryDecrypt(string cipherText)
    {
        try
        {
            var cipherBytes = Convert.FromBase64String(cipherText);
            using var encryptor = Aes.Create();
            using var pdb = new Rfc2898DeriveBytes(EncryptionKey, SaltBytes);
            encryptor.Key = pdb.GetBytes(32);
            encryptor.IV = pdb.GetBytes(16);

            using var ms = new MemoryStream();
            using (var cs = new CryptoStream(ms, encryptor.CreateDecryptor(), CryptoStreamMode.Write))
            {
                cs.Write(cipherBytes, 0, cipherBytes.Length);
            }

            return Encoding.Unicode.GetString(ms.ToArray());
        }
        catch
        {
            return null;
        }
    }

    public bool IsMatch(string inputPassword, string storedPassword)
    {
        if (string.IsNullOrWhiteSpace(storedPassword))
        {
            return false;
        }

        if (storedPassword.StartsWith("$2", StringComparison.Ordinal))
        {
            return BCrypt.Net.BCrypt.Verify(inputPassword, storedPassword);
        }

        var decrypted = TryDecrypt(storedPassword);
        if (!string.IsNullOrWhiteSpace(decrypted))
        {
            return string.Equals(inputPassword, decrypted, StringComparison.Ordinal);
        }

        return string.Equals(inputPassword, storedPassword, StringComparison.Ordinal);
    }
}
