#include <lauxlib.h>
#include <lua.h>
#include <string.h>

#define STB_IMAGE_IMPLEMENTATION
#define STB_IMAGE_STATIC
#include "stb_image.h"

#define IMAGE_META "stb_image.Image"

typedef struct {
  lua_Integer width;
  lua_Integer height;
  lua_Integer channels;
  stbi_uc* data;
} image_t;

static int _meta__gc(lua_State* L) {
  image_t* self = luaL_checkudata(L, 1, IMAGE_META);
  if (self->data) {
    stbi_image_free(self->data);
    self->data = NULL;
  }
  return 0;
}

static int _meta__index(lua_State* L) {
  image_t* self = luaL_checkudata(L, 1, IMAGE_META);
  const char* key = luaL_checkstring(L, 2);

  if (strcmp(key, "width") == 0) {
    lua_pushinteger(L, self->width);
  } else if (strcmp(key, "height") == 0) {
    lua_pushinteger(L, self->height);
  } else if (strcmp(key, "channels") == 0) {
    lua_pushinteger(L, self->channels);
  } else if (strcmp(key, "data") == 0) {
    lua_pushlstring(
      L, (const char*)self->data, self->width * self->height * self->channels
    );
  } else {
    lua_pushnil(L);
  }

  return 1;
}

static int _func_load(lua_State* L) {
  const char* path = luaL_checkstring(L, 1);
  lua_Integer req_channels = luaL_optinteger(L, 2, 4);
  int width, height, channels;

  stbi_uc* data = stbi_load(path, &width, &height, &channels, req_channels);
  if (!data) {
    lua_pushnil(L);
    return 1;
  }

  image_t* image = lua_newuserdata(L, sizeof(image_t));
  image->data = data;
  image->width = width;
  image->height = height;
  image->channels = req_channels > 0 ? req_channels : channels;

  luaL_getmetatable(L, IMAGE_META);
  lua_setmetatable(L, -2);

  return 1;
}

static const luaL_Reg _metatables[] = {
  {"__gc",    _meta__gc   },
  {"__index", _meta__index},
  {NULL,      NULL        }
};

static const luaL_Reg _functions[] = {
  {"load", _func_load},
  {NULL,   NULL      }
};

int luaopen_stb_image(lua_State* L) {
  luaL_newmetatable(L, IMAGE_META);
  luaL_setfuncs(L, _metatables, 0);
  lua_pop(L, 1);

  lua_newtable(L);
  luaL_setfuncs(L, _functions, 0);
  return 1;
}
