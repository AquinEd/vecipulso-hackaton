import '../models/community_brigade.dart';

/// Fictitious groups for local UI demonstration only.
const demoBrigades = [
  CommunityBrigade(
    id: 'demo-alamos',
    name: 'Brigada Los Álamos',
    startBlock: 1,
    endBlock: 5,
    memberCount: 12,
    type: BrigadeType.brigade,
    icon: BrigadeIcon.shield,
  ),
  CommunityBrigade(
    id: 'demo-progreso',
    name: 'Grupo El Progreso',
    startBlock: 6,
    endBlock: 10,
    memberCount: 8,
    type: BrigadeType.volunteers,
    icon: BrigadeIcon.community,
  ),
  CommunityBrigade(
    id: 'demo-salud',
    name: 'Equipo Salud Vecinal',
    startBlock: 11,
    endBlock: 15,
    memberCount: 6,
    type: BrigadeType.brigade,
    icon: BrigadeIcon.health,
  ),
  CommunityBrigade(
    id: 'demo-movilidad',
    name: 'Movilidad Solidaria',
    startBlock: 16,
    endBlock: 20,
    memberCount: 11,
    type: BrigadeType.volunteers,
    icon: BrigadeIcon.mobility,
  ),
];
