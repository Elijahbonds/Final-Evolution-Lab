import Nav from "./components/Nav";
import Hero from "./components/Hero";
import GameModes from "./components/GameModes";
import PRQSection from "./components/PRQSection";
import AcademySection from "./components/AcademySection";
import StreamingSection from "./components/StreamingSection";
import ShopSection from "./components/ShopSection";
import InstallSection from "./components/InstallSection";
import Footer from "./components/Footer";

export default function App() {
  return (
    <div className="min-h-screen">
      <Nav />
      <Hero />
      <GameModes />
      <PRQSection />
      <AcademySection />
      <StreamingSection />
      <ShopSection />
      <InstallSection />
      <Footer />
    </div>
  );
}
