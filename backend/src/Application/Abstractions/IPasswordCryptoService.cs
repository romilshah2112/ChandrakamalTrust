namespace OptimaHealthcare.Application.Abstractions;

public interface IPasswordCryptoService
{
    string Encrypt(string plainText);
    string? TryDecrypt(string cipherText);
    bool IsMatch(string inputPassword, string storedPassword);
}
