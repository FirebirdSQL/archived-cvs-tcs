/*
 *      PROGRAM:        Drop database
 *      MODULE:         drop.c
 *      DESCRIPTION:    Drop database
 *
 * The contents of this file are subject to the InterBase Public License
 * Version 1.0 (the "License"); you may not use this file except in
 * compliance with the License.
 *
 * You may obtain a copy of the License at http://www.Inprise.com/IPL.html.
 *
 * Software distributed under the License is distributed on an "AS IS"
 * basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
 * the License for the specific language governing rights and limitations
 * under the License.  The Original Code was created by Inprise
 * Corporation and its predecessors.
 *
 * Portions created by Inprise Corporation are Copyright (C) Inprise
 * Corporation. All Rights Reserved.
 *
 * Contributor(s): ______________________________________.
 */
#include <stdio.h>
#include <string.h>
#include <ibase.h>

#ifdef HP
#define RSH "remsh"
#else
#define RSH "rsh"
#endif

#define VERSION		"drop_gdb version 1.5"
#define USER		"SYSDBA"
#define PASS		"masterkey"

typedef char *DbName;

char machine[4];
int version;

char verbose = 0;
char fake_it = 0;
char username = 0;
char password = 0;

int main(argc, argv, envp)
int	argc;
char	**argv,**envp;
  {
  int cntr=0,
      iCntr=0,
      iDbIdx=0,
      fd;
  void  get_version();
  
  char buffer[256],
       *ptr,
       *dpb,
       *lpUsername,
       *lpPassword;
  
  DbName arDatabases[25];   /* holds all database names */
  
  isc_db_handle db_handle = 0;
  
  long status[20],
       lSqlCode;
  
  short dpb_length=0;
  
  /* process all command line arguments and store the database names in arDatabases */
  for(argv++; *argv; argv++)
    {
    if (**argv == '-')
      {
      switch((*argv)[1])
        {
        case 'u':  /* server username */
          argv++;
          lpUsername = *argv;
          username = 1;
          break;
          
        case 'p':  /* server password */
          argv++;
          lpPassword = *argv;
          password = 1;
          break;
          
        case 'v': /* turn on verbose mode */
          verbose = 1;
          break;
          
        case 'f':  /* just detach from the database, don't drop it */
          fake_it = 1;
          break;
          
        case 'z':  /* print the current version */
          printf("\t%s\n", VERSION);
          break;
          
        case 'h':
        case '?':  /* display command line options */
          printf("\nUsage: drop_gdb [-upvfz] db1[,db2,...]\n");
          printf("\t-u specify a username (default sysdba)\n");
          printf("\t-p specify a password (default masterkey)\n");
          printf("\t-v verbose mode\n");
          printf("\t-f don't drop, just detach\n");
          printf("\t-z displays the current version\n");
          printf("\t-h displays this message\n\n");
          return 0;
          break;
        }
      }
    else
      {
      /* catch the names of all databases here */
      arDatabases[iDbIdx++] = *argv;
      }
    }
  
   /* initialize dpb and only insert a username and password if the user
    * provided one on the command line
    */
  dpb=NULL;  
  if (username && password)
    {
    isc_expand_dpb(&dpb, 
      &dpb_length, 
      isc_dpb_user_name, 
      lpUsername, 
      isc_dpb_password, 
      lpPassword, 
      NULL);
    }
  else
    {
    lpUsername = USER;
    lpPassword = PASS;
    }
  
  /* loop through all the database names */
  for(iCntr=0; iCntr < iDbIdx; iCntr++)
    {
    
    /* print the database name, if verbose */
    if (verbose) printf("%s:\n", arDatabases[iCntr]);
    
    /* try to attach to the database, ignore file if fail */
    isc_attach_database(status, 
      strlen(arDatabases[iCntr]), 
      arDatabases[iCntr], 
      &db_handle, 
      dpb_length, 
      dpb);

    if (status[1])
      {
      if (verbose) isc_print_status(status);
      continue;
      }
    
    /* extract the version into global variables */
    version = 0;
    isc_version(&db_handle, get_version, 0);
    if (version == 0)
      {
      printf ("ERROR: no version information for '%s'\n", arDatabases[iCntr]);
      continue;
      }
    
    if (verbose) printf("\n");
    
    /* if the version is 4.0 then try isc_drop_database */
    if (version >= 40)
      {
      if (verbose) sprintf(buffer, "#drop database '%s'", arDatabases[iCntr]);
      if (!fake_it)
        {
        if (verbose) printf("\t%s\n", buffer+1);
        isc_drop_database(status, &db_handle);
        }
      else
        {
        if (verbose) printf("\t%s\n", buffer);
        isc_detach_database(status, &db_handle);
        }
      if (status[1])
        {
        isc_print_status(status);
        isc_detach_database(status, &db_handle);
        continue;
        }
      }
   
    else /* version is < 4.x */
      {
      isc_detach_database(status, &db_handle);
      
      /* check for ':' which implies a remote database */
      if (ptr = strchr(arDatabases[iCntr], ':'))
        {
        /* check for Alpha or VMS */
        if (!strcmp(machine, "VM") || !strcmp(machine, "AV"))
          {
          if (ptr[1] != '[')
            {
            *(ptr++) = '\0';
            /* just delete the file with the del command */
            sprintf(buffer, "#%s %s -n 'del %s;*'",RSH, arDatabases[iCntr], ptr);
            }
          }
        else
          {
          *(ptr++) = '\0';
          /* run GDEF remotely to delete database */
          /* add -u %s -pass %s to gdef for username and password  if there is one specified */
          sprintf(buffer, 
            "#%s %s echo delete database  \"\\'\"%s\"\\'\" \"|\" /usr/gds/sbin/rasu /usr/interbase/bin/gdef -u %s -pass %s ", 
            RSH, 
            arDatabases[iCntr], 
            ptr, 
            lpUsername, 
            lpPassword);
          }
        }
      else
        {
        /* run gdef locally to delete database */
        sprintf(buffer, 
          "#echo 'delete database \"%s\"' | gdef -u %s -pass %s", 
          arDatabases[iCntr], 
          lpUsername, 
          lpPassword);
        }
      
       /* if not fake_it then really make the call to get rid of the
        * database, skip over the first character which is a '#'
        * The '#' is there as a visual key that the command was not
        * really issued.
        */
      
      if (!fake_it)
        {
        if (verbose) printf("\t%s\n", buffer+1);
        system(buffer+1);
        }
      else
        {
        if (verbose) printf("\t%s\n", buffer);
        }
      }
}
return 0;
}

void get_version(format, arg)
char	*format, *arg;
/*
 * This funtion parses the version string information, and returns
 * machine (O.S) string and InterBase version number calculated from the
 * MAJOR and MINOR version numbers.
 */
{
#define VERSION_STRING "version \"%[A-Z]-%c%c.%c"
#define VERSION_MAJOR 1
#define VERSION_MINOR 2

  char ch[6],
    *ptr;
  int  tmp;
  
  /* if verbose, print all the version info */
  if (verbose) printf("\t%s\n", arg);
  
  /* look to see if the line contains the access method */
  if ((ptr = strstr(arg, "access method")) && (ptr = strstr(ptr, "version")))
  {
      /* extract the vital version info from the string */
      if (sscanf(ptr, VERSION_STRING, machine,
                 &ch[0], &ch[VERSION_MAJOR], &ch[VERSION_MINOR]))
         version = (ch[VERSION_MAJOR] - '0') * 10 + (ch[VERSION_MINOR] - '0');
  }
  
  /* look to see if the line contains the remote interface */
  if ((ptr = strstr(arg, "remote interface")) && (ptr = strstr(ptr, "version")))
  {
      if (sscanf(ptr, VERSION_STRING, machine,
                 &ch[0], &ch[VERSION_MAJOR], &ch[VERSION_MINOR])) 
      {
         tmp = (ch[VERSION_MAJOR] - '0') * 10 + (ch[VERSION_MINOR] - '0');

         /* use the lesser of the two versions */
         if (tmp < version) version = tmp;
      }
  }
}
