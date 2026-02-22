import { useState, type FormEvent } from 'react';
import { useContactForm } from '@/hooks/useContactForm';

export const ContactPage = () => {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');

  const { mutate, isPending, isSuccess, isError, error, reset } = useContactForm();

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();
    mutate(
      { name: name.trim(), email: email.trim(), message: message.trim() },
      {
        onSuccess: () => {
          setName('');
          setEmail('');
          setMessage('');
        },
      },
    );
  };

  const canSubmit = name.trim() && email.trim() && message.trim() && !isPending;

  return (
    <div className="shell contact-shell">
      <header className="hero-panel animate-pop">
        <div className="hero">
          <p className="eyebrow">Get in Touch</p>
          <h1>Let's talk about your next AWS project.</h1>
          <p>Have a question, suggestion, or just want to say hello? Drop a message below.</p>
        </div>
      </header>

      <div className="contact-card animate-rise">
        {isSuccess ? (
          <div className="contact-success">
            <div className="success-icon" aria-hidden="true">✓</div>
            <h2>Message sent!</h2>
            <p>Thanks for reaching out. I'll get back to you soon.</p>
            <button className="contact-btn" type="button" onClick={reset}>
              Send another message
            </button>
          </div>
        ) : (
          <form className="contact-form" onSubmit={handleSubmit} noValidate>
            <div className="form-group">
              <label htmlFor="contact-name">Name</label>
              <input
                id="contact-name"
                type="text"
                placeholder="Your name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
                autoComplete="name"
              />
            </div>

            <div className="form-group">
              <label htmlFor="contact-email">Email</label>
              <input
                id="contact-email"
                type="email"
                placeholder="you@example.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                autoComplete="email"
              />
            </div>

            <div className="form-group">
              <label htmlFor="contact-message">Message</label>
              <textarea
                id="contact-message"
                rows={5}
                placeholder="What would you like to discuss?"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                required
              />
            </div>

            {isError && (
              <p className="contact-error">
                {(error as any)?.response?.data?.message || 'Something went wrong. Please try again.'}
              </p>
            )}

            <button className="contact-btn" type="submit" disabled={!canSubmit}>
              {isPending ? 'Sending...' : 'Send Message'}
            </button>
          </form>
        )}
      </div>
    </div>
  );
};
