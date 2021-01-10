import macros

proc hasKind(node: NimNode, kind: NimNodeKind): bool =
  for c in node.children:
    if c.kind == kind:
      return true
  return false

proc `[]`(node: NimNode, kind: NimNodeKind): NimNode =
  for c in node.children:
    if c.kind == kind:
      return c
  return nil

template fieldPairs*[T: ref object](x: T): untyped =
  x[].fieldPairs

macro isObjectVariant*(v: typed): bool =
  ## Is this an object variant?
  var typ = v.getTypeImpl()
  if typ.kind == nnkSym:
    return ident("false")
  while typ.kind != nnkObjectTy:
    typ = typ[0].getTypeImpl()
  if typ[2].hasKind(nnkRecCase):
    ident("true")
  else:
    ident("false")

proc discriminator*(v: NimNode): NimNode =
  var typ = v.getTypeImpl()
  while typ.kind != nnkObjectTy:
    typ = typ[0].getTypeImpl()
  return typ[nnkRecList][nnkRecCase][nnkIdentDefs][nnkSym]

macro discriminatorFieldName*(v: typed): untyped =
  ## Turns into the discriminator field.
  return newLit($discriminator(v))

macro discriminatorField*(v: typed): untyped =
  ## Turns into the discriminator field.
  let
    fieldName = discriminator(v)
  return quote do:
    `v`.`fieldName`

macro new*(v: typed, d: typed): untyped =
  ## Creates a new object variant with the discriminator field.
  let
    typ = v.getTypeInst()
    fieldName = discriminator(v)
  return quote do:
    `v` = `typ`(`fieldName`: `d`)
