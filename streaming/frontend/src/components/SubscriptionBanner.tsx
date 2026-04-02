import React from 'react';
import type { SubscriptionInfo } from '../types';

interface Props {
  subscription: SubscriptionInfo;
  onSubscribe: () => void;
}

export function SubscriptionBanner({ subscription, onSubscribe }: Props) {
  if (subscription.status === 'active') return null;

  const getBannerContent = () => {
    switch (subscription.status) {
      case 'free_trial': {
        const hours = subscription.trialHoursRemaining;
        const urgency = hours <= 24 ? 'urgent' : hours <= 48 ? 'warning' : 'info';
        return {
          message: `FREE TRIAL: ${hours} hours remaining`,
          subtext: 'Subscribe for $6/week after trial',
          className: `trial-banner ${urgency}`,
        };
      }
      case 'expired':
        return {
          message: 'Trial Ended — Subscribe to Continue',
          subtext: 'Get full access to all 17 game modes & 23 exercises for $6/week',
          className: 'trial-banner expired',
        };
      case 'payment_failed':
        return {
          message: 'Payment Failed — Update Payment Method',
          subtext: 'Update your payment to continue your subscription',
          className: 'trial-banner expired',
        };
      case 'cancelled':
        return {
          message: 'Subscription Cancelled',
          subtext: 'Reactivate for $6/week to get back in the game',
          className: 'trial-banner expired',
        };
      default:
        return null;
    }
  };

  const content = getBannerContent();
  if (!content) return null;

  return (
    <div className={content.className}>
      <div className="banner-content">
        <span className="banner-message">{content.message}</span>
        <span className="banner-subtext">{content.subtext}</span>
      </div>
      <button className="btn-subscribe" onClick={onSubscribe}>
        {subscription.status === 'free_trial' ? 'SUBSCRIBE NOW' : 'SUBSCRIBE — $6/week'}
      </button>
    </div>
  );
}
