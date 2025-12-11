import type { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'
import { type ContainerCtx } from './types'

export interface IDatabaseConnection {
  // TODO: Define service interface
}

declare module './types' {
  interface ServicesList {
    databaseConnection: IDatabaseConnection
  }
}

export default function registerDatabaseConnection(
  container: ContainerCtx
) {
  container.bind('databaseConnection', {
    // TODO: Implement service registration
  })
}

export function mock(
  container: ContainerCtx
) {
  container.bind('databaseConnection', {
    // TODO: Implement mock service registration
  })
}

registerDatabaseConnection.mock = mock
