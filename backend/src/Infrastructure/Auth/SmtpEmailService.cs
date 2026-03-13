using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Configuration;
using OptimaHealthcare.Application.Abstractions;

namespace OptimaHealthcare.Infrastructure.Auth;

/// <summary>
/// Sends password reset emails via SMTP. Reads Host, Port, From, Password from configuration (SMTP section).
/// </summary>
public sealed class SmtpEmailService : IEmailService
{
    private readonly IConfiguration _configuration;

    public SmtpEmailService(IConfiguration configuration)
    {
        _configuration = configuration;
    }

    public async Task SendPasswordResetEmailAsync(string toEmail, string resetToken, CancellationToken cancellationToken = default)
    {
        var host = _configuration["SMTP:Host"];
        var portStr = _configuration["SMTP:Port"];
        var from = _configuration["SMTP:From"];
        var password = _configuration["SMTP:Password"];
        var enableSslStr = _configuration["SMTP:enableSsl"];
        var alias = _configuration["SMTP:Alias"] ?? from ?? string.Empty;

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from) || string.IsNullOrWhiteSpace(password))
        {
            throw new InvalidOperationException("SMTP:Host, SMTP:From, and SMTP:Password must be set in configuration.");
        }

        var port = int.TryParse(portStr, out var p) ? p : 587;
        var enableSsl = !string.Equals(enableSslStr, "false", StringComparison.OrdinalIgnoreCase);

        using var client = new SmtpClient(host, port)
        {
            Credentials = new NetworkCredential(from, password),
            EnableSsl = enableSsl
        };
        var subject = "Reset your password";
        var body = $"Use this code to reset your password: {resetToken}\n\nThis code expires in 1 hour.";
        using var message = new MailMessage
        {
            From = new MailAddress(from, alias),
            Subject = subject,
            Body = body,
            IsBodyHtml = false
        };
        message.To.Add(toEmail);
        await client.SendMailAsync(message, cancellationToken);
    }

    public async Task SendAppointmentReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentStartTime,
        CancellationToken cancellationToken = default)
    {
        var subject = "Reminder: Upcoming appointment";
        var timeStr = appointmentStartTime.ToString("f");
        var body = $"Hello {patientName},\n\nThis is a reminder of your upcoming appointment:\n\n"
            + $"Doctor: {doctorName}\nClinic: {clinicName}\nDate & time: {timeStr}\n\n"
            + "Please arrive a few minutes early. Contact the clinic if you need to reschedule.";
        await SendMailInternalAsync(toEmail, subject, body, cancellationToken);
    }

    public async Task SendFollowUpReminderAsync(
        string toEmail,
        string patientName,
        string doctorName,
        string clinicName,
        DateTime appointmentDate,
        CancellationToken cancellationToken = default)
    {
        var subject = "Follow-up: How are you feeling?";
        var dateStr = appointmentDate.ToString("D");
        var body = $"Hello {patientName},\n\nYou had an appointment with Dr. {doctorName} at {clinicName} on {dateStr}.\n\n"
            + "We hope you are doing well. If you have any concerns or need a follow-up visit, please contact the clinic.";
        await SendMailInternalAsync(toEmail, subject, body, cancellationToken);
    }

    private async Task SendMailInternalAsync(
        string toEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        var host = _configuration["SMTP:Host"];
        var portStr = _configuration["SMTP:Port"];
        var from = _configuration["SMTP:From"];
        var password = _configuration["SMTP:Password"];
        var enableSslStr = _configuration["SMTP:enableSsl"];
        var alias = _configuration["SMTP:Alias"] ?? from ?? string.Empty;

        if (string.IsNullOrWhiteSpace(host) || string.IsNullOrWhiteSpace(from) || string.IsNullOrWhiteSpace(password))
        {
            throw new InvalidOperationException("SMTP:Host, SMTP:From, and SMTP:Password must be set in configuration.");
        }

        var port = int.TryParse(portStr, out var p) ? p : 587;
        var enableSsl = !string.Equals(enableSslStr, "false", StringComparison.OrdinalIgnoreCase);
        await SendMailAsync(host, port, enableSsl, from, alias, password, toEmail, subject, body, cancellationToken);
    }

    private static async Task SendMailAsync(
        string host,
        int port,
        bool enableSsl,
        string from,
        string alias,
        string password,
        string toEmail,
        string subject,
        string body,
        CancellationToken cancellationToken)
    {
        using var client = new SmtpClient(host, port)
        {
            Credentials = new NetworkCredential(from, password),
            EnableSsl = enableSsl
        };
        using var message = new MailMessage
        {
            From = new MailAddress(from, alias),
            Subject = subject,
            Body = body,
            IsBodyHtml = false
        };
        message.To.Add(toEmail);
        await client.SendMailAsync(message, cancellationToken);
    }
}
