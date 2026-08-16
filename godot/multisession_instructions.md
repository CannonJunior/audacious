  Step 2 — Launch four parallel sessions                                                                                                            
                                                                                                                                                  
  Each session owns exactly one new file:                                                                                                           
                                                                                                                                                  
  ┌─────────┬────────────────────────┬────────────────────────────┬────────────────────────────────────────────────┐
  │ Session │     File to create     │           Phases           │                   Key inputs                   │
  ├─────────┼────────────────────────┼────────────────────────────┼────────────────────────────────────────────────┤
  │ A       │ SuitThrusterVFX.gd     │ 2                          │ GasRouter, PowerRouter, EventBus signals       │                                
  ├─────────┼────────────────────────┼────────────────────────────┼────────────────────────────────────────────────┤
  │ B       │ SuitLegIK.gd           │ 5                          │ Skeleton, raycast, thigh=0.4686m, calf=0.4975m │                                
  ├─────────┼────────────────────────┼────────────────────────────┼────────────────────────────────────────────────┤                              
  │ C       │ SuitSecondaryMotion.gd │ 3, 4, 7                    │ Spine bones, clavicle bones, head, neck        │
  ├─────────┼────────────────────────┼────────────────────────────┼────────────────────────────────────────────────┤
  │ D       │ SuitEmissionGlow.gd    │ 6 (materials) + 8 (events) │ MeshInstance3D, 11 emission PNGs               │                                
  └─────────┴────────────────────────┴────────────────────────────┴────────────────────────────────────────────────┘
                                                                                                                                                    
  Session B (leg IK) is the longest by far. Sessions A, C, D are roughly similar in scope and can finish independently.                           
                                                                                                                                                    
  What to put in each session's briefing                                                                                                          
                                                                                                                                                    
  Every session needs to start cold, so each briefing must include:                                                                               
  - The complete audit findings above (bone names, lengths, FX positions, material structure)                                                       
  - The full failure review for its specific phase(s)                                                                                             
  - The subsystem interface definition (what methods the coordinator will call, what the context dict contains)                                     
  - The bone name map constants, so sessions don't re-derive them                                              
  - The constraint that it must not modify SuitModelVisuals.gd or any other session's file                                                          
                                                                                                                                                  
  The briefings for B (leg IK) and D (emission glow) need the most detail — B because the IK math is intricate, D because the material-replacement  
  approach after runtime GLB loading has a confirmed failure mode (must duplicate materials before writing, check is StandardMaterial3D before    
  casting).   
                                                                                                                                                  
  ┌────────────────────────┬────────────┬───────────────────────────────────────────────────────────────────────────────────────────────────────┐   
  │          File          │   Status   │                                           What it contains                                            │   
  ├────────────────────────┼────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
  │ SuitModelVisuals.gd    │ Complete   │ Coordinator: BONE_NAMES map (all 50 bones), root lean/bob, bone index cache, subsystem orchestration  │   
  ├────────────────────────┼────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
  │ SuitThrusterVFX.gd     │ Working    │ Existing thruster bone animation migrated and running; particle stubs with detailed implementation    │   
  │                        │ stub       │ comments                                                                                              │ 
  ├────────────────────────┼────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
  │ SuitLegIK.gd           │ Stub       │ Full IK math documented in comments; confirmed bone lengths (0.4686m, 0.4975m); step system design;   │   
  │                        │            │ _clear_leg_pose() already written                                                                     │   
  ├────────────────────────┼────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┤   
  │ SuitSecondaryMotion.gd │ Stub       │ Spring-damper arrays allocated; event connections wired; _apply_jiggle_impulse() written; all four    │   
  │                        │            │ systems in commented pseudocode                                                                       │   
  ├────────────────────────┼────────────┼───────────────────────────────────────────────────────────────────────────────────────────────────────┤ 
  │ SuitEmissionGlow.gd    │ Stub       │ Event connections wired; _on_suit_landed / _on_boost_activated written; material name → texture path  │   
  │                        │            │ map documented                                                                                        │   
  └────────────────────────┴────────────┴───────────────────────────────────────────────────────────────────────────────────────────────────────┘ 
                                                                                                                                                    
  What each parallel session brief must include:                                                                                                    
  - The full plan from this conversation (bone audit results, IK math, failure modes)                                                             
  - The subsystem interface: setup(...) + tick(ctx) where ctx has the keys listed in the coordinator                                                
  - An explicit instruction: do not modify SuitModelVisuals.gd                                      
  - The confirmed constraint on BoneAttachment3D (use get_bone_global_pose() manually instead)                                                    
                                                                                                                                                    
  The game will run unchanged after this commit — SuitThrusterVFX contains the migrated thruster bone code, so there is no regression.
                                                                                                                                                    
✻ Worked for 7m 44s · 1 local agent still running                                                                                                   
                                                                                                                                                    
● Agent "Save animation architecture to project memory" completed                                                                                   
                                                                                                                                                    
● Memory saved. The architecture is committed to long-term memory so future sessions can pick it up without re-reading this conversation.           
                                                                                                                                                    
  You're ready to launch the four parallel sessions. Each one should be given:                                                                    
                                                                                                                                                    
  1. The full updated plan from this conversation (literature review through failure review)                                                      
  2. The bone audit data (bone names, chain lengths, FX bone positions, material surface map)                                                       
  3. The subsystem interface spec (setup() + tick(ctx) with the context dict keys)                                                                
  4. The specific failure modes for its phase(s)                                                                                                    
  5. The hard rule: only edit the one file it owns                                                                                                
                                                                                                                                                    
  Session B (leg IK) will take longest — start it first.                                                                                            
                                                                                                                                                    
※ recap: Building procedural animation for the mech suit. Completed the coordinator refactor and four subsystem stubs — ready to launch parallel    
  Claude Code sessions for Sessions A through D.  
