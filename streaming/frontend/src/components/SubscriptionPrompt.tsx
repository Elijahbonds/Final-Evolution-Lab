import React from 'react';

interface Props {
  onSubscribe: () => void;
  onClose: () => void;
}

export function SubscriptionPrompt({ onSubscribe, onClose }: Props) {
  return (
    <div className="subscription-overlay">
      <div className="subscription-prompt">
        <h2>UNLOCK YOUR FULL EVOLUTION</h2>
        
        <div className="benefits-list">
          <div className="benefit">✅ 17 game modes across 8 sports</div>
          <div className="benefit">✅ 23 animated exercise demonstrations</div>
          <div className="benefit">✅ 5 pre-built workout programs</div>
          <div className="benefit">✅ Custom workout builder</div>
          <div className="benefit">✅ Creator challenges & content</div>
          <div className="benefit">✅ Progress tracking & personal records</div>
          <div className="benefit">✅ Form validation & coaching</div>
        </div>

        <div className="price-section">
          <div className="price">$6<span>/week</span></div>
          <div className="price-note">Cancel anytime</div>
        </div>

        <div className="prompt-actions">
          <button className="btn-subscribe-main" onClick={onSubscribe}>
            SUBSCRIBE NOW
          </button>
          <button className="btn-maybe-later" onClick={onClose}>
            Maybe Later
          </button>
        </div>
      </div>
    </div>
  );
}
