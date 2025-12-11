We want to create some sort of engine that reads the file system
and based on some options it creates new files and folders

## The tool we are building this for

We have a Inversion of Control container for js/ts library in npm public registry called [@computerwwizards/dependency-injection](https://www.npmjs.com/package/@computerwwwizards/dependency-injection) that in summary has primitives to lazy resolve dependency injection (this reminds me to update this library and have a option to eager load things upon registration. Also I know there are some mature libs in the wild about DI and IoC but they use reflection and in my client side apps, native script mobile apps and some durable functions that reflection was causing a lot of churn. Nevertheless we plan supporting adapaters from thjose libs to our interfaces because some projects depend heavily on that kind of libraries, and also create adapters in the other direction, but to avoid reflection we would need some kind of compilator for ts to create the needed boilerplate that replaces that runtime refelction, we are working on that and we need to investigate further about how reflecction behaves in engines like v8 and spider monkey). 

Well, when using this library we usually create some "global containers" (usually one) and then "child containers" to scope what we are doing. The problem comes that there is a lot of boilerplate involving that. Nevertheless not everyone woul dwant the same strcuture so we need to find the little pieces of code we usually tend to write.

There is a special kind of container that is the most used because it has a `use` method, which registers one or a series of **"handlers"**.Actually this handlers are just functions that have acess to the instance, is like a plugin system, it is just for covenience, because instead of doing:

```ts
import { 
  PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

// service interface definitions should be defined also, we
// are ommiting it because this is an example
interface ServicesList {
  serviceA: IServiceA
  serviceB: IServiceB
  serviceC: IServiceC
}

const container = new PreProcessDependencyContainerWithUse<ServicesList>();

container
  .bind('serviceA',{
    // lot of code
  })
  .bind('serviceB',{
    // more code
  })
  .bind('serviceC',{
    // tire to read all the bindings
  })
```

We can logical separate that in a function, that mutates the container, something like


```ts
// types.ts

import { 
  type PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

export interface ServicesList {

}

export type ContainerCtx = PreProcessDependencyContainerWithUse<ServicesList>
```

```ts
// registerServiceA.ts
import { 
  type PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

import { ContainerCtx } from './types.ts'

// not always we woudl need a interface, sometimes a type for a plain function
export interface IServiceA{
  // some contract
}

// we agument the ServiceList
declare module './types.ts' {
  interface ServicesList{
    serviceA: IServiceA
  }
}

export default function registerDeps(
  container: ContainerCtx
){
  container.bind('serviceA', {
    //some code
  })
}

export function mock(
  container: ContainerCtx
){
  container.bind('serviceA', {
    // some code that only mocks
  })
}

// we attach the mock function to the main function for convenience
registerDeps.mock

```
And we do the same with all the other "services" so later we can

```ts
// mainContainer.ts
import { 
  PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

import { ServicesList } from './types.ts';

import registerServiceA  from './registerServiceA.ts';
import registerServiceB  from './registerServiceB.ts';
import registerServiceC  from './registerServiceC.ts';

const container = new PreProcessDependencyContainerWithUse<ServicesList>();

registerServiceA(container);
registerServiceB(container);
registerServiceC.mock(container); // We can change to the mock implementation whenever we need
```

But beacuse we have the `use` method we can also have two variations of this

```ts
// mainContainer.ts
import { 
  PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

import { ServicesList } from './types.ts';

import registerServiceA  from './registerServiceA.ts';
import registerServiceB  from './registerServiceB.ts';
import registerServiceC  from './registerServiceC.ts';

const container = new PreProcessDependencyContainerWithUse<ServicesList>();

container
  .use(
    registerServiceA,
    registerServiceB,
    registerServiceC.mock     // We can activate the mock whenever we like
  )
```

Or

```ts
// mainContainer.ts
import { 
  PreProcessDependencyContainerWithUse
} from '@computerwwwizards/dependency-injection'

import { ServicesList } from './types.ts';

import registerServiceA  from './registerServiceA.ts';
import registerServiceB  from './registerServiceB.ts';
import registerServiceC  from './registerServiceC.ts';

const container = new PreProcessDependencyContainerWithUse<ServicesList>();

container
  .use(registerServiceA)
  .use(registerServiceB)
  .use(registerServiceC.mock)
```

The part of the real registration is a example because you know there are edge cases,
for instance imagine we have a feature flag provider that loads first and depending on its
values we decide if we use the normal registration fn or the mock one. Or imagine this other escenario we have this in the cleint side of a web app and then we subscribe to some configuration server that has server sent events that well in real time can change which registration function we should use.

For those cases the `mainContainer.ts` code is not enough, so we would need to be flexible about that, but hte registration functions well they apparently always will exist.

So we need rigth now to discover and plan what MVP we can delvier about htis, I mean like what is the minimum boilerplate that we can generate and it is going to be usable.