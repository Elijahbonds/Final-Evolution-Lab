//
//  FinalEvolutionLabUnreal-Bridging-Header.h
//  FinalEvolutionLabUnreal
//
//  Exposes C / Objective-C symbols to Swift. This target is Swift + ObjC only; Unreal Engine C++ is NOT compiled here.
//

#ifndef FinalEvolutionLabUnreal_Bridging_Header_h
#define FinalEvolutionLabUnreal_Bridging_Header_h

// MARK: - Native host bridge (Unity / __Internal → Swift notifications)
// Implemented by NativeBridge/FELNativeCallProxy.m — exercise complete, XP, rep shards.
#import "FELNativeCallProxy.h"

// MARK: - Unreal C++ subsystems (reference for Gold Master / UE embed)
// The following types live under UnrealStarter/BasketballGame/ and are part of the Unreal game module only.
// They are NOT #importable in this iOS target (no UE toolchain / no generated headers here).
// When you merge an Unreal iOS export into Xcode, add ObjC++ shims and link the UE static libs; then expose only C symbols above.
//
//   • UFELAvatarSnapshotSubsystem   — UFELAvatarSnapshotSubsystem.h / .cpp
//   • UFELAssetRegistrySubsystem    — UFELAssetRegistrySubsystem.h / .cpp (WarmUpForBioSync, venue async load)
//   • UFELNeuroMechanicBridgeSubsystem — FELNeuroMechanicBridgeSubsystem.h / .cpp (readiness → pawn ApplyReadiness)
//
// Swift name collision note: UFELCreatorRevenueSubsystem in this app is a Swift @Observable type (Services/UFELCreatorRevenueSubsystem.swift),
// not the Unreal module; no ObjC import required.

#endif /* FinalEvolutionLabUnreal_Bridging_Header_h */
