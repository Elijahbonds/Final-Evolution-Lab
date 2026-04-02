import Nav from "./components/Nav";
import Hero from "./components/Hero";
import GameModes from "./components/GameModes";
import DownloadSection from "./components/DownloadSection";
import VideoShowcase from "./components/VideoShowcase";
import PRQSection from "./components/PRQSection";
import AcademySection from "./components/AcademySection";
import BodyScanSection from "./components/BodyScanSection";
import FamilySharingSection from "./components/FamilySharingSection";
import ShardEconomySection from "./components/ShardEconomySection";
import StreamingSection from "./components/StreamingSection";
import PricingSection from "./components/PricingSection";
import ShopSection from "./components/ShopSection";
import InstallSection from "./components/InstallSection";
import Footer from "./components/Footer";

export default function App() {
  return (
    <div className="min-h-screen">
      <Nav />
      <Hero />
      <GameModes />
      <BodyScanSection />
      <ShardEconomySection />
      <FamilySharingSection />
      <PricingSection />
      <DownloadSection />
      <VideoShowcase />
      <PRQSection />
      <AcademySection />
      <StreamingSection />
      <ShopSection />
      <InstallSection />
      <Footer />
    </div>
  );
}
